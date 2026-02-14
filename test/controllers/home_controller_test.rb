require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders for unauthenticated visitor" do
    get root_url
    assert_response :success
  end

  test "renders landing page for authenticated user" do
    sign_in_as(users(:one))
    get root_url
    assert_response :success
  end
end
