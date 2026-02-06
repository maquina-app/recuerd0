require "test_helper"

class Analytics::ApiRequestTest < ActiveSupport::TestCase
  test "validates presence of http_method, path, and status" do
    api_request = Analytics::ApiRequest.new
    assert_not api_request.valid?
    assert_includes api_request.errors[:http_method], "can't be blank"
    assert_includes api_request.errors[:path], "can't be blank"
    assert_includes api_request.errors[:status], "can't be blank"
  end

  test "creates api request with valid attributes and stores duration_ms as integer" do
    api_request = Analytics::ApiRequest.create!(
      http_method: "GET",
      path: "/workspaces.json",
      status: 200,
      duration_ms: 42,
      account_id: accounts(:one).id,
      user_id: users(:one).id,
      ip_address: "10.0.0.0",
      user_agent: "curl/7.88",
      created_at: Time.current
    )
    api_request.reload

    assert api_request.persisted?
    assert_equal 42, api_request.duration_ms
    assert_kind_of Integer, api_request.duration_ms
  end
end
