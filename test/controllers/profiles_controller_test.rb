require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  # show
  test "show renders profile page for authenticated user" do
    sign_in_as(@user)
    get profile_url
    assert_response :success
  end

  test "show loads user's access tokens" do
    sign_in_as(@user)
    get profile_url
    assert_response :success
    assert_select "[data-component='card']#access-tokens", count: 1
    assert_select "div.divide-y" # tokens list is present
  end

  test "show redirects unauthenticated user to login" do
    get profile_url
    assert_redirected_to new_session_url
  end

  # update
  test "update changes user name and redirects with notice" do
    sign_in_as(@user)
    patch profile_url, params: {user: {name: "New Name"}}

    assert_redirected_to profile_path
    assert_equal "New Name", @user.reload.name
  end

  test "update rejects name that is too long" do
    sign_in_as(@user)
    patch profile_url, params: {user: {name: "a" * 81}}

    assert_response :unprocessable_entity
  end

  test "update clears name when blank submitted" do
    sign_in_as(@user)
    patch profile_url, params: {user: {name: ""}}

    assert_redirected_to profile_path
    assert_equal "", @user.reload.name
  end

  # A newly created token is rendered into an input's value= attribute, and
  # attributes are serialized into Turbo's page snapshot — so without no-cache
  # a Drive visit away and a Back press re-rendered the plaintext secret the
  # page had just promised would never be shown again.
  test "show opts out of the turbo cache so a revealed token cannot come back" do
    sign_in_as(@user)
    get profile_url

    assert_response :success
    assert_select "meta[name='turbo-cache-control'][content='no-cache']", count: 1
  end

  # .oauth.active also required expires_at in the future, but
  # AccessToken.find_by_refresh_token gates only on revoked_at — so an app whose
  # access token had expired disappeared from the list while still able to mint
  # new ones, leaving the user nothing to revoke.
  test "connected apps still lists a grant whose access token has expired" do
    client = OauthClient.create!(
      client_name: "Expired Probe Client",
      redirect_uris: ["https://example.test/callback"].to_json,
      registered_at: Time.current
    )
    token = @user.access_tokens.create!(
      description: "Expired but refreshable",
      permission: "read_only",
      oauth_client: client,
      expires_at: 1.day.ago,
      token_digest: Digest::SHA256.hexdigest("expired_access_token_probe"),
      refresh_token_digest: Digest::SHA256.hexdigest("live_refresh_token_probe")
    )

    # The condition that actually grants access: find_by_refresh_token gates
    # only on revoked_at, so this grant is still live.
    assert_equal token, AccessToken.find_by_refresh_token("live_refresh_token_probe")

    sign_in_as(@user)
    get profile_url

    assert_response :success
    # `assigns` is gone in modern Rails; assert on the rendered page instead —
    # which is the thing the user was being denied.
    assert_select "body", text: /Expired Probe Client/
  end
end
