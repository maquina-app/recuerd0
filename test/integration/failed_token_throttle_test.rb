require "test_helper"

# Tokens are too long to guess, so a flood of bad ones is noise rather than an attack on
# a credential. It still costs a job per failure, and an address sharing egress with
# working agents mustn't lock them out, so only failures count and a valid token passes.
class FailedTokenThrottleTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  LIMIT = Authentication::FAILED_TOKEN_LIMIT

  setup do
    @original_store = ActionController::Base.cache_store
    ActionController::Base.cache_store = ActiveSupport::Cache::MemoryStore.new
    @workspace = workspaces(:one)
  end

  teardown do
    ActionController::Base.cache_store = @original_store
  end

  test "REST answers 401 up to the limit, then 429" do
    fail_rest(LIMIT)
    assert_response :unauthorized

    fail_rest
    assert_response :too_many_requests
    assert_equal "RATE_LIMITED", response.parsed_body.dig("error", "code")
    assert_equal "60", response.headers["Retry-After"]
  end

  test "a valid token from the same address still works past the limit" do
    fail_rest(LIMIT + 1)
    assert_response :too_many_requests

    get workspaces_url(format: :json), headers: auth_headers("test_full_token_456")
    assert_response :success

    mcp_post(mcp_rpc("tools/list"), token: "test_full_token_456")
    assert_response :success
  end

  test "another address isn't affected" do
    fail_rest(LIMIT + 1)
    assert_response :too_many_requests

    get workspaces_url(format: :json), headers: auth_headers("nope").merge("REMOTE_ADDR" => "203.0.113.9")
    assert_response :unauthorized
  end

  test "the limit clears after the window" do
    fail_rest(LIMIT + 1)
    assert_response :too_many_requests

    travel Authentication::FAILED_TOKEN_WINDOW + 1.second do
      fail_rest
      assert_response :unauthorized
    end
  end

  test "failures past the limit stop writing analytics" do
    fail_rest(LIMIT)

    assert_no_enqueued_jobs(only: Analytics::RecordEventJob) { fail_rest }
    assert_response :too_many_requests
  end

  test "failures under the limit are still recorded" do
    assert_enqueued_with(job: Analytics::RecordEventJob) { fail_rest }
  end

  test "a valid token never adds to the count" do
    (LIMIT + 1).times { get workspaces_url(format: :json), headers: auth_headers("test_full_token_456") }

    fail_rest
    assert_response :unauthorized
  end

  test "a browser with no token is unaffected" do
    fail_rest(LIMIT + 1)

    get new_session_url
    assert_response :success
  end

  # MCP

  test "MCP answers 401 up to the limit, then 429 in JSON-RPC" do
    LIMIT.times { mcp_post(mcp_rpc("tools/list"), token: "nope") }
    assert_response :unauthorized

    body = mcp_post(mcp_rpc("tools/list"), token: "nope")
    assert_response :too_many_requests
    assert_equal(-32_000, body.dig("error", "code"))
    assert_equal "60", response.headers["Retry-After"]
  end

  test "REST and MCP share one count" do
    fail_rest(LIMIT)

    mcp_post(mcp_rpc("tools/list"), token: "nope")
    assert_response :too_many_requests
  end

  test "an MCP request with no token is discovery, so it doesn't count" do
    (LIMIT + 1).times { mcp_post(mcp_rpc("tools/list")) }
    assert_response :unauthorized
    assert_match(/resource_metadata/, response.headers["WWW-Authenticate"])

    fail_rest
    assert_response :unauthorized
  end

  test "an OAuth token for another resource counts as a failure" do
    client = OauthClient.create!(client_name: "Elsewhere", redirect_uris: JSON.generate(["https://client.example/callback"]))
    token = users(:one).access_tokens.create!(oauth_client: client, permission: "full_access",
      oauth_scope: "memories:read memories:write", audience: "https://elsewhere.example/mcp", expires_at: 1.hour.from_now)

    LIMIT.times { mcp_post(mcp_rpc("tools/list"), token: token.raw_token) }
    assert_response :unauthorized

    mcp_post(mcp_rpc("tools/list"), token: token.raw_token)
    assert_response :too_many_requests
  end

  private

  def fail_rest(times = 1)
    times.times { get workspaces_url(format: :json), headers: auth_headers("nope") }
  end
end
