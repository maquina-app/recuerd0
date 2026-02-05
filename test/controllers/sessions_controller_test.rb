require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET new renders login form with signup link" do
    get new_session_url
    assert_response :success
    assert_select "a[href='#{new_registration_path}']", "Sign up"
  end

  test "POST create with valid credentials logs in user" do
    user = users(:one)

    post session_url, params: {email_address: user.email_address, password: "password"}

    assert_redirected_to workspaces_path
    assert cookies[:session_id].present?
  end

  test "POST create with invalid credentials shows error" do
    post session_url, params: {email_address: "wrong@example.com", password: "wrong"}

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "[data-variant='destructive']"
  end
end
