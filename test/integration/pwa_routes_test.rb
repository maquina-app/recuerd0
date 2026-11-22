require "test_helper"

# Production logged a 500 for /manifest.zip: the routes took any format Rails
# knows, and only json and js have templates.
class PwaRoutesTest < ActionDispatch::IntegrationTest
  test "the manifest and the service worker answer in their own format" do
    get "/manifest.json"
    assert_response :success
    assert_equal "application/json", response.media_type

    get "/service-worker.js"
    assert_response :success
  end

  test "any other format is not found rather than an error" do
    %w[/manifest.zip /manifest.pdf /service-worker.zip /service-worker.json].each do |path|
      get path
      assert_response :not_found, path
    end
  end
end
