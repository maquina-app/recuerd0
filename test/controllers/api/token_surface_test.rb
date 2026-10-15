require "test_helper"

# A bearer token reaches the API surface and nothing else. Before this, any
# controller answered to a token as long as the Accept header said JSON, so a
# read-only token could mint a full-access one, approve an OAuth consent, or
# destroy an account. Each route below must answer 401 and leave no trace.
class ApiTokenSurfaceTest < ActionDispatch::IntegrationTest
  TOKENS = {read_only: "test_read_token_123", full_access: "test_full_token_456"}.freeze

  setup do
    @user = users(:one)
    @member = users(:member)
    @deleted_workspace = workspaces(:deleted)
    @memory = memories(:versioned_parent)
    @client = OauthClient.create!(client_name: "Claude", redirect_uris: JSON.generate(["https://claude.ai/cb"]))
  end

  test "every off-surface route answers 401 to a valid token, in either format" do
    each_token_and_format do |headers|
      off_surface_requests.each do |verb, path, params|
        assert_no_side_effects do
          public_send(verb, path, params: params, headers: headers)
        end

        assert_response :unauthorized, "#{verb.to_s.upcase} #{path} (#{headers.inspect})"
        assert_equal "UNAUTHORIZED", JSON.parse(response.body).dig("error", "code")
      end
    end
  end

  test "a read-only token cannot mint a full-access token" do
    assert_no_difference "AccessToken.count" do
      post profile_access_tokens_url,
        params: {access_token: {description: "Escalated", permission: "full_access"}},
        headers: auth_headers(TOKENS[:read_only]).merge("Accept" => "application/json")
    end

    assert_response :unauthorized
  end

  test "an invalid Bearer never falls back to the signed-in session" do
    sign_in_as @user

    get workspaces_url(format: :json), headers: auth_headers("not_a_real_token")
    assert_response :unauthorized
    assert_equal "UNAUTHORIZED", JSON.parse(response.body).dig("error", "code")

    get workspaces_url, headers: auth_headers("not_a_real_token")
    assert_response :unauthorized
    assert_equal "UNAUTHORIZED", JSON.parse(response.body).dig("error", "code")

    # The session itself is untouched — it just does not rescue a bad token.
    get workspaces_url
    assert_response :success
  end

  test "a read-only token is refused on an HTML write, not redirected" do
    post archive_workspace_url(workspaces(:one)),
      headers: auth_headers(TOKENS[:read_only]).merge("Accept" => "text/html")

    assert_response :forbidden
    assert_equal "FORBIDDEN", JSON.parse(response.body).dig("error", "code")
    assert workspaces(:one).reload.active?
  end

  test "a session-cookie JSON write needs an authenticity token" do
    # Sign in first: the session form itself is CSRF-protected, and the flow
    # under test starts from an already-authenticated browser.
    sign_in_as @user
    workspace = workspaces(:one)

    with_forgery_protection do
      assert_no_difference "Memory.count" do
        post workspace_memories_url(workspace_id: workspace.id, format: :json),
          params: {memory: {title: "Forged", body: "from another site"}}
      end
      assert_response :unprocessable_entity

      assert_difference "Memory.count", 1 do
        post workspace_memories_url(workspace_id: workspace.id, format: :json),
          params: {memory: {title: "Legitimate", body: "from the app"}},
          headers: {"X-CSRF-Token" => authenticity_token}
      end
      assert_response :created
    end
  end

  private

  # verb, path, params — one row per route that must stay off the token surface.
  def off_surface_requests
    [
      [:post, profile_access_tokens_url, {access_token: {description: "Escalated", permission: "full_access"}}],
      [:get, profile_url, nil],
      [:patch, profile_url, {user: {name: "Renamed"}}],
      [:patch, profile_password_url, {password_challenge: "password", password: "newpassword", password_confirmation: "newpassword"}],
      [:patch, account_url, {account: {name: "Renamed"}}],
      [:delete, account_url, nil],
      [:post, account_invitation_url, {email_address: "intruder@example.com"}],
      [:post, account_exports_url, nil],
      [:delete, account_user_url(@member), nil],
      [:get, oauth_authorize_url, oauth_authorization_params],
      [:post, oauth_authorize_url, oauth_authorization_params.merge(approved: "true")],
      [:post, create_pin_url(pinnable_type: "Memory", pinnable_id: @memory.id), nil],
      [:post, restore_deleted_workspace_url(@deleted_workspace), nil],
      [:delete, destroy_deleted_workspace_url(@deleted_workspace), nil],
      [:post, workspace_memory_version_consolidation_url(workspace_id: @memory.workspace_id, memory_id: @memory.id, version_id: @memory.id), nil],
      [:post, onboarding_dismiss_url, nil]
    ]
  end

  def oauth_authorization_params
    {
      client_id: @client.client_id,
      redirect_uri: "https://claude.ai/cb",
      response_type: "code",
      code_challenge: "a" * 43,
      code_challenge_method: "S256"
    }
  end

  def each_token_and_format
    TOKENS.each_value do |token|
      [{}, {"Accept" => "application/json"}].each do |accept|
        yield auth_headers(token).merge(accept)
      end
    end
  end

  def assert_no_side_effects(&block)
    assert_no_difference ["AccessToken.count", "OauthAuthorizationCode.count", "Pin.count", "Memory.count"], &block

    assert @deleted_workspace.reload.deleted?, "deleted workspace was restored or destroyed"
    assert_not @user.account.reload.deleted?, "account was soft-deleted"
    assert_nil @user.reload.onboarding_dismissed_at, "onboarding was dismissed"
  end

  def with_forgery_protection
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  # Reads the real token off the layout's meta tag, the same place
  # @rails/request.js reads it, rather than fabricating one.
  def authenticity_token
    get workspaces_url
    css_select("meta[name='csrf-token']").first["content"]
  end
end
