require "test_helper"

class AccessTokenTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "raw_token is generated on create" do
    token = @user.access_tokens.create!(permission: "read_only")
    assert token.raw_token.present?
    assert_equal 32, token.raw_token.length
  end

  test "token digest is stored" do
    token = @user.access_tokens.create!(permission: "read_only")
    expected_digest = Digest::SHA256.hexdigest(token.raw_token)
    assert_equal expected_digest, token.token_digest
  end

  test "find_by_token with valid token" do
    token = @user.access_tokens.create!(permission: "read_only")
    raw_token = token.raw_token

    found = AccessToken.find_by_token(raw_token)
    assert_equal token, found
  end

  test "find_by_token with invalid token" do
    found = AccessToken.find_by_token("invalid_token")
    assert_nil found
  end

  test "find_by_token with blank token" do
    assert_nil AccessToken.find_by_token(nil)
    assert_nil AccessToken.find_by_token("")
  end

  test "permission validation rejects invalid values" do
    access_token = @user.access_tokens.build(permission: "invalid")
    assert_not access_token.valid?
    assert_includes access_token.errors[:permission], "is not included in the list"
  end

  test "permission defaults to read_only" do
    access_token = @user.access_tokens.create!
    assert_equal "read_only", access_token.permission
  end

  test "read_only? returns true for read_only permission" do
    token = access_tokens(:read_only_token)
    assert token.read_only?
    assert_not token.full_access?
  end

  test "full_access? returns true for full_access permission" do
    token = access_tokens(:full_access_token)
    assert token.full_access?
    assert_not token.read_only?
  end

  test "user association" do
    token = access_tokens(:read_only_token)
    assert_equal users(:one), token.user
  end

  test "touch_last_used updates timestamp" do
    token = access_tokens(:read_only_token)
    assert_nil token.last_used_at

    token.touch_last_used!
    assert token.last_used_at.present?
    assert_in_delta Time.current, token.last_used_at, 1.second
  end

  test "user has many access_tokens" do
    assert_respond_to @user, :access_tokens
    assert_includes @user.access_tokens, access_tokens(:read_only_token)
  end

  test "destroying user destroys access_tokens" do
    token_id = access_tokens(:read_only_token).id
    users(:one).destroy
    assert_nil AccessToken.find_by(id: token_id)
  end

  # OAuth extensions

  test "find_by_token excludes revoked tokens" do
    token = @user.access_tokens.create!(permission: "read_only")
    raw = token.raw_token
    token.revoke!

    assert_nil AccessToken.find_by_token(raw)
  end

  test "find_by_token excludes expired tokens" do
    token = @user.access_tokens.create!(permission: "read_only", expires_at: 1.hour.ago)

    assert_nil AccessToken.find_by_token(token.raw_token)
  end

  test "find_by_token still returns non-expiring manual tokens" do
    token = @user.access_tokens.create!(permission: "read_only")

    assert_equal token, AccessToken.find_by_token(token.raw_token)
  end

  test "permission_for_scope maps write scope to full_access" do
    assert_equal "full_access", AccessToken.permission_for_scope("memories:read memories:write")
    assert_equal "read_only", AccessToken.permission_for_scope("memories:read")
    assert_equal "read_only", AccessToken.permission_for_scope(nil)
  end

  test "assign_refresh_token exposes raw and stores digest" do
    token = @user.access_tokens.build(permission: "read_only")
    raw = token.assign_refresh_token!
    token.save!

    assert_equal raw, token.raw_refresh_token
    assert_equal Digest::SHA256.hexdigest(raw), token.refresh_token_digest
    assert_equal token, AccessToken.find_by_refresh_token(raw)
  end

  test "find_by_refresh_token still works after the access token has expired" do
    token = @user.access_tokens.build(permission: "read_only", expires_at: 1.hour.ago)
    raw = token.assign_refresh_token!
    token.save!

    # Access token is expired, but the refresh token must still resolve.
    assert_nil AccessToken.find_by_token(token.raw_token)
    assert_equal token, AccessToken.find_by_refresh_token(raw)
  end

  test "find_by_refresh_token excludes revoked tokens" do
    token = @user.access_tokens.build(permission: "read_only", expires_at: 1.hour.from_now)
    raw = token.assign_refresh_token!
    token.save!
    token.revoke!

    assert_nil AccessToken.find_by_refresh_token(raw)
  end

  test "manual and oauth scopes partition tokens" do
    client = OauthClient.create!(client_name: "App", redirect_uris: JSON.generate(["https://example.com/cb"]))
    oauth_token = @user.access_tokens.create!(permission: "read_only", oauth_client: client, expires_at: 1.hour.from_now)
    manual_token = access_tokens(:read_only_token)

    assert_includes @user.access_tokens.oauth, oauth_token
    assert_not_includes @user.access_tokens.oauth, manual_token
    assert_includes @user.access_tokens.manual, manual_token
    assert_not_includes @user.access_tokens.manual, oauth_token
  end
end
