require "test_helper"

# Exercises the full OAuth 2.1 + PKCE authorization-code flow end to end:
# DCR registration -> consent -> code exchange -> refresh.
class Oauth::FlowTest < ActionDispatch::IntegrationTest
  PKCE_VERIFIER = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk".freeze
  PKCE_CHALLENGE = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM".freeze
  REDIRECT_URI = "https://claude.ai/api/mcp/auth_callback".freeze

  setup do
    @user = users(:one)
  end

  test "well-known documents are public and describe the server" do
    get "/.well-known/oauth-protected-resource"
    assert_response :success
    resource = JSON.parse(response.body)
    assert_match %r{/mcp\z}, resource["resource"]

    # RFC 9728 path-suffixed variant (probed first by many clients)
    get "/.well-known/oauth-protected-resource/mcp"
    assert_response :success

    get "/.well-known/oauth-authorization-server"
    assert_response :success
    meta = JSON.parse(response.body)
    assert_equal ["S256"], meta["code_challenge_methods_supported"]
    assert_match %r{/oauth/token\z}, meta["token_endpoint"]
  end

  test "browser MCP clients get CORS headers on discovery and OAuth endpoints" do
    get "/.well-known/oauth-authorization-server"
    assert_equal "*", response.headers["access-control-allow-origin"]

    # Preflight is answered without hitting the controller
    process :options, "/oauth/token"
    assert_response :no_content
    assert_equal "*", response.headers["access-control-allow-origin"]
    assert_includes response.headers["access-control-allow-headers"], "Authorization"
  end

  test "dynamic client registration creates a public client" do
    post "/oauth/register", params: {client_name: "Claude", redirect_uris: [REDIRECT_URI]}
    assert_response :created

    body = JSON.parse(response.body)
    assert body["client_id"].present?
    assert_equal "none", body["token_endpoint_auth_method"]
    assert_equal [REDIRECT_URI], body["redirect_uris"]
  end

  test "full authorization code flow issues and refreshes tokens" do
    client = register_client

    # Consent screen requires authentication
    sign_in_as(@user)
    get "/oauth/authorize", params: authorize_params(client)
    assert_response :success

    # Approve -> redirected back with a code
    post "/oauth/authorize", params: authorize_params(client).merge(approved: "true")
    assert_response :redirect
    code = redirect_param("code")
    assert code.present?
    assert_equal "xyz", redirect_param("state")

    # Exchange the code for tokens
    post "/oauth/token", params: {
      grant_type: "authorization_code",
      client_id: client.client_id,
      code: code,
      redirect_uri: REDIRECT_URI,
      code_verifier: PKCE_VERIFIER
    }
    assert_response :success
    tokens = JSON.parse(response.body)
    assert tokens["access_token"].present?
    assert tokens["refresh_token"].present?
    assert_equal "Bearer", tokens["token_type"]
    assert AccessToken.find_by_token(tokens["access_token"]).present?

    # The code is single-use
    assert_nil OauthAuthorizationCode.find_by(code: code)

    # Refresh rotates both tokens — and must work AFTER the 1h access token expired
    old_refresh = tokens["refresh_token"]
    travel 2.hours do
      assert_nil AccessToken.find_by_token(tokens["access_token"]), "access token should be expired"

      # client_id is required now: the grant is bound to the client it was
      # issued to, so the token alone is no longer enough.
      post "/oauth/token", params: {grant_type: "refresh_token", client_id: client.client_id, refresh_token: old_refresh}
      assert_response :success
      refreshed = JSON.parse(response.body)
      assert_not_equal tokens["access_token"], refreshed["access_token"]
      assert_nil AccessToken.find_by_refresh_token(old_refresh)
      assert AccessToken.find_by_token(refreshed["access_token"]).present?
    end
  end

  test "token exchange fails with a wrong PKCE verifier" do
    client = register_client
    sign_in_as(@user)
    post "/oauth/authorize", params: authorize_params(client).merge(approved: "true")
    code = redirect_param("code")

    post "/oauth/token", params: {
      grant_type: "authorization_code",
      client_id: client.client_id,
      code: code,
      redirect_uri: REDIRECT_URI,
      code_verifier: "the-wrong-verifier"
    }
    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]
  end

  test "denying consent redirects with access_denied" do
    client = register_client
    sign_in_as(@user)
    post "/oauth/authorize", params: authorize_params(client).merge(approved: "false")

    assert_response :redirect
    assert_equal "access_denied", redirect_param("error")
  end

  test "revocation revokes the matching token" do
    token = @user.access_tokens.create!(permission: "read_only", expires_at: 1.hour.from_now,
      oauth_client: register_client)
    raw = token.raw_token

    post "/oauth/revoke", params: {token: raw}
    assert_response :ok
    assert token.reload.revoked?
    assert_nil AccessToken.find_by_token(raw)
  end

  test "a refresh token is bound to the client it was issued to" do
    client_a = register_client
    client_b = OauthClient.create!(client_name: "Other app", redirect_uris: JSON.generate([REDIRECT_URI]))

    sign_in_as(@user)
    post "/oauth/authorize", params: authorize_params(client_a).merge(approved: "true")
    code = redirect_param("code")

    post "/oauth/token", params: {
      grant_type: "authorization_code",
      client_id: client_a.client_id,
      code: code,
      redirect_uri: REDIRECT_URI,
      code_verifier: PKCE_VERIFIER
    }
    assert_response :success
    refresh_token = JSON.parse(response.body)["refresh_token"]

    # Client B may not redeem A's grant, and the attempt must not rotate it.
    post "/oauth/token", params: {
      grant_type: "refresh_token",
      client_id: client_b.client_id,
      refresh_token: refresh_token
    }
    assert_response :bad_request
    assert_equal "invalid_grant", JSON.parse(response.body)["error"]

    post "/oauth/token", params: {
      grant_type: "refresh_token",
      client_id: client_a.client_id,
      refresh_token: refresh_token
    }
    assert_response :success
    rotated = JSON.parse(response.body)
    assert rotated["access_token"].present?
    assert_not_equal refresh_token, rotated["refresh_token"]
  end

  private

  def register_client
    OauthClient.create!(client_name: "Claude", redirect_uris: JSON.generate([REDIRECT_URI]))
  end

  def authorize_params(client)
    {
      client_id: client.client_id,
      response_type: "code",
      redirect_uri: REDIRECT_URI,
      scope: "memories:read memories:write",
      state: "xyz",
      code_challenge: PKCE_CHALLENGE,
      code_challenge_method: "S256"
    }
  end

  def redirect_param(name)
    Rack::Utils.parse_query(URI(response.location).query)[name]
  end
end
