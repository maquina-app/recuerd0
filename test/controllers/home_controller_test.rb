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
end
