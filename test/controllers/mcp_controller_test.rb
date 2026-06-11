require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = @user.account
    @workspace = workspaces(:one)
    @client = OauthClient.create!(client_name: "Claude", redirect_uris: JSON.generate(["https://claude.ai/cb"]))

    @full_token = oauth_token(permission: "full_access", scope: "memories:read memories:write")
    @read_token = oauth_token(permission: "read_only", scope: "memories:read")
  end

  test "rejects requests without a Bearer token" do
    post "/mcp", params: rpc("tools/list").to_json, headers: json_headers
    assert_response :unauthorized
    assert_match "resource_metadata", response.headers["WWW-Authenticate"]
    assert_equal(-32_001, JSON.parse(response.body)["error"]["code"])
  end

  test "rejects an expired token" do
    expired = oauth_token(permission: "read_only", scope: "memories:read", expires_at: 1.hour.ago)
    result = mcp(rpc("tools/list"), token: expired.raw_token)
    assert_response :unauthorized
    assert_nil result["result"]
  end

  test "initialize echoes a supported protocol version and sets a session id" do
    payload = rpc("initialize")
    payload[:params][:protocolVersion] = "2025-03-26"
    result = mcp(payload, token: @read_token.raw_token)

    assert_response :success
    assert_equal "2025-03-26", result["result"]["protocolVersion"]
    assert response.headers["Mcp-Session-Id"].present?
  end

  test "initialize falls back to the latest version for an unknown request" do
    payload = rpc("initialize")
    payload[:params][:protocolVersion] = "2099-01-01"
    result = mcp(payload, token: @read_token.raw_token)

    assert_equal McpController::LATEST_PROTOCOL_VERSION, result["result"]["protocolVersion"]
  end

  test "notifications are acknowledged with 202 and no body" do
    post "/mcp",
      params: {jsonrpc: "2.0", method: "notifications/initialized"}.to_json,
      headers: auth_headers(@read_token.raw_token).merge(json_headers)

    assert_response :accepted
    assert_predicate response.body.strip, :empty?
  end

  test "tools/list returns the five tools" do
    result = mcp(rpc("tools/list"), token: @read_token.raw_token)
    names = result["result"]["tools"].map { |t| t["name"] }
    assert_equal Mcp::ToolDefinitions::NAMES.sort, names.sort
  end

  test "list_workspaces returns the account's workspaces" do
    result = mcp(rpc("tools/call", name: "list_workspaces"), token: @read_token.raw_token)
    payload = JSON.parse(result["result"]["content"].first["text"])
    assert_includes payload.map { |w| w["name"] }, @workspace.name
  end

  test "create_memory is denied for a read_only token" do
    result = mcp(
      rpc("tools/call", name: "create_memory",
        arguments: {workspace_id: @workspace.id.to_s, title: "X", content: "Y"}),
      token: @read_token.raw_token
    )
    assert_equal(-32_001, result["error"]["code"])
  end

  test "create_memory succeeds with a full_access token" do
    assert_difference -> { @workspace.memories.count }, 1 do
      result = mcp(
        rpc("tools/call", name: "create_memory",
          arguments: {workspace_id: @workspace.id.to_s, title: "From MCP", content: "Body", category: "decision"}),
        token: @full_token.raw_token
      )
      payload = JSON.parse(result["result"]["content"].first["text"])
      assert_equal "From MCP", payload["title"]
    end
  end

  test "tools enforce account isolation" do
    other_memory = memories(:two) # belongs to account two
    result = mcp(
      rpc("tools/call", name: "read_memory", arguments: {memory_id: other_memory.id.to_s}),
      token: @full_token.raw_token
    )
    assert result["result"]["isError"]
    assert_equal "Memory not found", result["result"]["content"].first["text"]
  end

  private

  def oauth_token(permission:, scope:, expires_at: 1.hour.from_now)
    @user.access_tokens.create!(
      oauth_client: @client,
      permission: permission,
      oauth_scope: scope,
      expires_at: expires_at
    )
  end

  def rpc(method, name: nil, arguments: nil)
    params = {}
    params[:name] = name if name
    params[:arguments] = arguments if arguments
    {jsonrpc: "2.0", id: 1, method: method, params: params}
  end

  def json_headers
    {"Content-Type" => "application/json"}
  end

  def mcp(payload, token:)
    post "/mcp", params: payload.to_json, headers: auth_headers(token).merge(json_headers)
    JSON.parse(response.body)
  end
end
