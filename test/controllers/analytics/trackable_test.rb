require "test_helper"

class Analytics::TrackableTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:one)
    @read_only_token = "test_read_token_123"
  end

  test "track_api_request enqueues RecordApiRequestJob for JSON requests" do
    assert_enqueued_with(job: Analytics::RecordApiRequestJob) do
      get workspace_memories_url(@workspace, format: :json),
        headers: auth_headers(@read_only_token)
    end
  end

  test "track_api_request does not fire for HTML requests" do
    sign_in_as(@user)

    get workspace_memory_url(@workspace, @memory)

    api_request_jobs = enqueued_jobs.select { |j| j[:job] == Analytics::RecordApiRequestJob }
    assert_equal 0, api_request_jobs.size
  end

  test "track_api_request anonymizes IP address" do
    perform_enqueued_jobs do
      get workspace_memories_url(@workspace, format: :json),
        headers: auth_headers(@read_only_token)
    end

    api_request = Analytics::ApiRequest.last
    assert_not_nil api_request
    assert_equal "127.0.0.0", api_request.ip_address
  end

  test "track_api_request captures http_method path and status" do
    perform_enqueued_jobs do
      get workspace_memories_url(@workspace, format: :json),
        headers: auth_headers(@read_only_token)
    end

    api_request = Analytics::ApiRequest.last
    assert_not_nil api_request
    assert_equal "GET", api_request.http_method
    assert_includes api_request.path, "/workspaces/"
    assert_equal 200, api_request.status
  end

  test "track_api_request captures duration_ms" do
    perform_enqueued_jobs do
      get workspace_memories_url(@workspace, format: :json),
        headers: auth_headers(@read_only_token)
    end

    api_request = Analytics::ApiRequest.last
    assert_not_nil api_request
    assert_kind_of Integer, api_request.duration_ms
    assert api_request.duration_ms >= 0
  end
end
