require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET new renders login form with signup link" do
    get new_session_url
    assert_response :success
    assert_select "a[href='#{new_registration_path}']", "Sign up"
  end

  test "GET new redirects authenticated user to workspaces" do
    sign_in_as(users(:one))
    get new_session_url
    assert_redirected_to workspaces_path
  end

  test "POST create with valid credentials logs in user" do
    user = users(:one)

    post session_url, params: {email_address: user.email_address, password: "password"}

    assert_redirected_to workspaces_path
    assert cookies[:session_id].present?
  end

  test "POST create redirects authenticated user to workspaces" do
    sign_in_as(users(:one))
    post session_url, params: {email_address: "other@example.com", password: "password"}
    assert_redirected_to workspaces_path
  end

  test "POST create with invalid credentials shows error" do
    post session_url, params: {email_address: "wrong@example.com", password: "wrong"}

    assert_response :unprocessable_entity
    assert_select "[data-variant='destructive']"
    assert_select "input[name='email_address'][value='wrong@example.com']"
  end

  test "a session past the absolute limit is signed out even while in use" do
    user = users(:one)
    sign_in_as(user)
    session = user.sessions.order(:created_at).last
    session.update_columns(created_at: (Session::ABSOLUTE_TIMEOUT + 1.day).ago, updated_at: Time.current)

    get workspaces_url

    assert_redirected_to new_session_path
    assert_not Session.exists?(session.id)
  end
end
