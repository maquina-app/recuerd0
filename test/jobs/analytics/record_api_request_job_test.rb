require "test_helper"

class Analytics::RecordApiRequestJobTest < ActiveJob::TestCase
  test "creates an Analytics::ApiRequest record with correct attributes" do
    attributes = {
      http_method: "GET",
      path: "/workspaces.json",
      status: 200,
      duration_ms: 35,
      account_id: accounts(:one).id,
      user_id: users(:one).id,
      ip_address: "10.0.0.0",
      user_agent: "curl/7.88",
      created_at: Time.current
    }

    assert_difference "Analytics::ApiRequest.count", 1 do
      Analytics::RecordApiRequestJob.perform_now(attributes)
    end

    api_request = Analytics::ApiRequest.last
    assert_equal "GET", api_request.http_method
    assert_equal "/workspaces.json", api_request.path
    assert_equal 200, api_request.status
    assert_equal 35, api_request.duration_ms
  end

  test "silently discards invalid records without raising" do
    assert_nothing_raised do
      Analytics::RecordApiRequestJob.perform_now({http_method: nil, path: nil, status: nil, created_at: Time.current})
    end

    assert_no_difference "Analytics::ApiRequest.count" do
      Analytics::RecordApiRequestJob.perform_now({http_method: nil, path: nil, status: nil, created_at: Time.current})
    end
  end
end
