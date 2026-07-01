require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders for unauthenticated visitor" do
    get root_url
    assert_response :success
  end

  test "redirects authenticated user to workspaces" do
    sign_in_as(users(:one))
    get root_url
    assert_redirected_to workspaces_path
  end

  test "handles malformed Accept header without 500" do
    # Crawlers can send unparseable Accept headers, leaving a nil entry in
    # request.accepts. api_request? must not blow up on it (regression).
    get root_url, headers: {"Accept" => ",,"}
    assert_response :success
  end
end
