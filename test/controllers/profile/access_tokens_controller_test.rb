require "test_helper"

class Profile::AccessTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @token = access_tokens(:read_only_token)
  end

  # create
  test "create creates token and redirects with flash new_token" do
    sign_in_as(@user)

    assert_difference "AccessToken.count", 1 do
      post profile_access_tokens_url, params: {
        access_token: {permission: "read_only"}
      }
    end

    assert_redirected_to profile_path
    assert flash[:new_token].present?
  end

  test "create with description stores description" do
    sign_in_as(@user)

    post profile_access_tokens_url, params: {
      access_token: {description: "My CI token", permission: "full_access"}
    }

    token = AccessToken.last
    assert_equal "My CI token", token.description
    assert_equal "full_access", token.permission
  end

  test "create with invalid permission rejects" do
    sign_in_as(@user)

    assert_no_difference "AccessToken.count" do
      post profile_access_tokens_url, params: {
        access_token: {permission: "invalid"}
      }
    end

    assert_redirected_to profile_path
    assert flash[:alert].present?
  end

  # destroy
  test "destroy deletes token and redirects with notice" do
    sign_in_as(@user)

    assert_difference "AccessToken.count", -1 do
      delete profile_access_token_url(@token)
    end

    assert_redirected_to profile_path
  end

  test "destroy cannot delete another user's token" do
    sign_in_as(@user)
    other_token = access_tokens(:other_user_token)

    assert_no_difference "AccessToken.count" do
      delete profile_access_token_url(other_token)
    end

    assert_response :not_found
  end

  test "unauthenticated access redirects to login" do
    post profile_access_tokens_url, params: {
      access_token: {permission: "read_only"}
    }

    assert_redirected_to new_session_url
  end
end
