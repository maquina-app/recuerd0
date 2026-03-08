require "test_helper"

class ErrorsControllerTest < ActionDispatch::IntegrationTest
  # These error routes are invoked by config.exceptions_app = routes
  # when an exception occurs. In tests, we exercise them directly.
  # We use .json extension to bypass ActionDispatch::Static which
  # would otherwise serve the public/*.html files at these paths.

  test "400 returns structured JSON" do
    get "/400.json"

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_equal "BAD_REQUEST", json.dig("error", "code")
    assert_equal 400, json.dig("error", "status")
    assert_includes json.dig("error", "message"), "URL-encoded"
  end

  test "404 returns structured JSON" do
    get "/404.json"

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "NOT_FOUND", json.dig("error", "code")
    assert_equal 404, json.dig("error", "status")
  end

  test "422 returns structured JSON" do
    get "/422.json"

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "UNPROCESSABLE_ENTITY", json.dig("error", "code")
    assert_equal 422, json.dig("error", "status")
  end

  test "500 returns structured JSON" do
    get "/500.json"

    assert_response :internal_server_error
    json = JSON.parse(response.body)
    assert_equal "INTERNAL_SERVER_ERROR", json.dig("error", "code")
    assert_equal 500, json.dig("error", "status")
  end

  test "404 renders HTML error page for browser requests" do
    get "/this-page-does-not-exist"

    assert_response :not_found
    assert_includes response.body, "404"
  end
end
