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

  test "tools/list returns the six tools" do
    result = mcp(rpc("tools/list"), token: @read_token.raw_token)
    names = result["result"]["tools"].map { |t| t["name"] }
    assert_equal Mcp::ToolDefinitions::NAMES.sort, names.sort
    assert_includes names, "create_version"
  end

  test "tools/list advertises tags and category inputs on write tools" do
    result = mcp(rpc("tools/list"), token: @read_token.raw_token)
    tools = result["result"]["tools"].index_by { |t| t["name"] }

    create_props = tools["create_memory"]["inputSchema"]["properties"]
    assert_equal "array", create_props["tags"]["type"]

    update_props = tools["update_memory"]["inputSchema"]["properties"]
    assert_equal "array", update_props["tags"]["type"]
    assert_equal Mcp::ToolDefinitions::CATEGORIES, update_props["category"]["enum"]
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

  test "create_memory persists tags and stamps source with the client name" do
    result = nil
    assert_difference -> { @workspace.memories.count }, 1 do
      result = mcp(
        rpc("tools/call", name: "create_memory",
          arguments: {workspace_id: @workspace.id.to_s, title: "From MCP", content: "Body",
                      category: "decision", tags: ["newsletter", "mailer"]}),
        token: @full_token.raw_token
      )
    end

    payload = JSON.parse(result["result"]["content"].first["text"])
    assert_equal "From MCP", payload["title"]
    assert_equal ["newsletter", "mailer"], payload["tags"]
    assert_equal "Claude", payload["source"]

    memory = @workspace.memories.find(payload["id"])
    assert_equal ["newsletter", "mailer"], memory.tags
    assert_equal "Claude", memory.source
  end

  test "create_memory ignores a client-supplied source and uses the OAuth client name" do
    result = mcp(
      rpc("tools/call", name: "create_memory",
        arguments: {workspace_id: @workspace.id.to_s, title: "Spoof", content: "x", source: "Evil App"}),
      token: @full_token.raw_token
    )
    payload = JSON.parse(result["result"]["content"].first["text"])
    assert_equal "Claude", payload["source"]
    assert_equal "Claude", @workspace.memories.find(payload["id"]).source
  end

  test "read_memory returns tags, source, and version" do
    memory = Memory.create_with_content(@workspace,
      title: "Tagged", content: "Body", tags: ["a", "b"], source: "Claude")

    result = mcp(
      rpc("tools/call", name: "read_memory", arguments: {memory_id: memory.id.to_s}),
      token: @read_token.raw_token
    )
    payload = JSON.parse(result["result"]["content"].first["text"])
    assert_equal ["a", "b"], payload["tags"]
    assert_equal "Claude", payload["source"]
    assert_equal 1, payload["version"]
    assert_equal "Body", payload["content"]
  end

  test "list_memories includes tags and source" do
    Memory.create_with_content(@workspace,
      title: "Listed", content: "Body", tags: ["x"], source: "Claude")

    result = mcp(
      rpc("tools/call", name: "list_memories", arguments: {workspace_id: @workspace.id.to_s}),
      token: @read_token.raw_token
    )
    payload = JSON.parse(result["result"]["content"].first["text"])
    listed = payload.find { |m| m["title"] == "Listed" }
    assert_equal ["x"], listed["tags"]
    assert_equal "Claude", listed["source"]
  end

  test "update_memory changes category and tags in place without a new version" do
    memory = Memory.create_with_content(@workspace, title: "Edit me", content: "Body")

    assert_no_difference -> { memory.all_versions.count } do
      result = mcp(
        rpc("tools/call", name: "update_memory",
          arguments: {memory_id: memory.id.to_s, category: "preference", tags: ["edited"]}),
        token: @full_token.raw_token
      )
      payload = JSON.parse(result["result"]["content"].first["text"])
      assert_equal "preference", payload["category"]
      assert_equal ["edited"], payload["tags"]
    end

    memory.reload
    assert_equal "preference", memory.category
    assert_equal ["edited"], memory.tags
  end

  test "create_version appends a new version and read_memory returns its content" do
    memory = Memory.create_with_content(@workspace, title: "v1", content: "First")

    assert_difference -> { memory.all_versions.count }, 1 do
      result = mcp(
        rpc("tools/call", name: "create_version",
          arguments: {memory_id: memory.id.to_s, content: "Second", tags: ["v2"]}),
        token: @full_token.raw_token
      )
      payload = JSON.parse(result["result"]["content"].first["text"])
      assert_equal "Claude", payload["source"]
      assert_equal ["v2"], payload["tags"]
    end

    read = mcp(
      rpc("tools/call", name: "read_memory", arguments: {memory_id: memory.id.to_s}),
      token: @read_token.raw_token
    )
    read_payload = JSON.parse(read["result"]["content"].first["text"])
    assert_equal "Second", read_payload["content"]
    assert_equal 2, read_payload["version"]
  end

  test "create_version is denied for a read_only token" do
    memory = Memory.create_with_content(@workspace, title: "v1", content: "First")
    result = mcp(
      rpc("tools/call", name: "create_version",
        arguments: {memory_id: memory.id.to_s, content: "Second"}),
      token: @read_token.raw_token
    )
    assert_equal(-32_001, result["error"]["code"])
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
