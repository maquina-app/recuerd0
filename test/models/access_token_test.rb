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
end
