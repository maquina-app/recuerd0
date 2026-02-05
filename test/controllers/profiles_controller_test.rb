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
end
