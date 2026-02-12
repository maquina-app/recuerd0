require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET terms renders terms of service without authentication" do
    get terms_url
    assert_response :success
    assert_select "h1", "Terms of Service"
  end

  test "GET privacy renders privacy policy without authentication" do
    get privacy_url
    assert_response :success
    assert_select "h1", "Privacy Policy"
  end

  test "GET pricing renders pricing page without authentication" do
    get pricing_url
    assert_response :success
  end

  test "GET license renders license page without authentication" do
    get license_url
    assert_response :success
    assert_select "h1", "License"
  end
end
