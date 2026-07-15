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

  test "tools/list returns every defined tool" do
    result = mcp(rpc("tools/list"), token: @read_token.raw_token)
    names = result["result"]["tools"].map { |t| t["name"] }
    assert_equal Mcp::ToolDefinitions::NAMES.sort, names.sort
    assert_includes names, "create_version"
    assert_includes names, "read_memories"
    assert_includes names, "link_memories"
    assert_includes names, "workspace_stats"
    assert_includes names, "suggest_merge_candidates"
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

  test "list_memories returns a paginated envelope with tags and source" do
    Memory.create_with_content(@workspace,
      title: "Listed", content: "Body", tags: ["x"], source: "Claude")

    payload = call_tool("list_memories", {workspace_id: @workspace.id.to_s})

    assert_kind_of Array, payload["memories"]
    assert_kind_of Integer, payload["total_count"]
    assert_includes [true, false], payload["has_more"]
    listed = payload["memories"].find { |m| m["title"] == "Listed" }
    assert_equal ["x"], listed["tags"]
    assert_equal "Claude", listed["source"]
  end

  test "list_memories paginates via limit and offset" do
    3.times { |i| Memory.create_with_content(@workspace, title: "Page#{i}", content: "b") }

    first = call_tool("list_memories", {workspace_id: @workspace.id.to_s, limit: 2, offset: 0})
    assert_equal 2, first["memories"].size
    assert first["has_more"]
    assert_equal 2, first["next_offset"]

    second = call_tool("list_memories",
      {workspace_id: @workspace.id.to_s, limit: 2, offset: first["next_offset"]})
    assert_operator first["total_count"], :==, second["total_count"]
    overlap = first["memories"].map { |m| m["id"] } & second["memories"].map { |m| m["id"] }
    assert_empty overlap, "pages should not overlap"
  end

  test "list_memories category filter matches the displayed (current version) category" do
    memory = Memory.create_with_content(@workspace, title: "Evolving", content: "b", category: "general")
    memory.create_version!(category: "decision", content: "b2")

    general = call_tool("list_memories", {workspace_id: @workspace.id.to_s, category: "general"})
    decision = call_tool("list_memories", {workspace_id: @workspace.id.to_s, category: "decision"})

    assert general["memories"].none? { |m| m["title"] == "Evolving" },
      "should not match its stale root category"
    assert general["memories"].all? { |m| m["category"] == "general" }
    listed = decision["memories"].find { |m| m["title"] == "Evolving" }
    assert_equal "decision", listed["category"]
  end

  test "list_memories rejects an invalid category" do
    result = mcp(
      rpc("tools/call", name: "list_memories",
        arguments: {workspace_id: @workspace.id.to_s, category: "bogus"}),
      token: @read_token.raw_token
    )
    assert result["result"]["isError"]
    assert_match "Invalid category", result["result"]["content"].first["text"]
  end

  test "read_memories returns multiple bodies and reports missing ids" do
    a = Memory.create_with_content(@workspace, title: "A", content: "Body A")
    b = Memory.create_with_content(@workspace, title: "B", content: "Body B")

    payload = call_tool("read_memories",
      {memory_ids: [a.id.to_s, b.id.to_s, "999999"]})

    titles = payload["memories"].map { |m| m["title"] }
    assert_equal ["A", "B"], titles.sort
    assert_equal ["Body A"], payload["memories"].select { |m| m["title"] == "A" }.map { |m| m["content"] }
    assert_includes payload["missing"], "999999"
  end

  test "list_memory_links, link_memories, and unlink_memories round-trip" do
    a = Memory.create_with_content(@workspace, title: "A", content: "b")
    b = Memory.create_with_content(@workspace, title: "B", content: "b")

    link = call_tool("link_memories", {memory_id: a.id.to_s, to_memory_id: b.id.to_s}, token: @full_token.raw_token)
    assert link["linked"]

    links = call_tool("list_memory_links", {memory_id: a.id.to_s})
    assert_equal ["B"], links.map { |m| m["title"] }

    unlink = call_tool("unlink_memories", {memory_id: a.id.to_s, to_memory_id: b.id.to_s}, token: @full_token.raw_token)
    assert unlink["unlinked"]
    assert_empty call_tool("list_memory_links", {memory_id: a.id.to_s})
  end

  test "link_memories is denied for a read_only token" do
    a = Memory.create_with_content(@workspace, title: "A", content: "b")
    b = Memory.create_with_content(@workspace, title: "B", content: "b")
    result = mcp(
      rpc("tools/call", name: "link_memories",
        arguments: {memory_id: a.id.to_s, to_memory_id: b.id.to_s}),
      token: @read_token.raw_token
    )
    assert_equal(-32_001, result["error"]["code"])
  end

  test "workspace_stats returns category counts and totals" do
    Memory.create_with_content(@workspace, title: "S1", content: "b", category: "decision")
    Memory.create_with_content(@workspace, title: "S2", content: "b", category: "decision", tags: ["alpha"])

    stats = call_tool("workspace_stats", {workspace_id: @workspace.id.to_s})

    assert_operator stats["counts_by_category"]["decision"], :>=, 2
    assert_equal Memory::CATEGORIES.sort, stats["counts_by_category"].keys.sort
    assert_operator stats["total_memories"], :>=, 2
    assert stats["top_tags"].any? { |t| t["tag"] == "alpha" }
  end

  test "suggest_merge_candidates clusters near-duplicate memories" do
    Memory.create_with_content(@workspace, title: "Deploy runbook", content: "b", tags: ["ops"])
    Memory.create_with_content(@workspace, title: "Deploy runbook", content: "b", tags: ["ops"])

    clusters = call_tool("suggest_merge_candidates", {workspace_id: @workspace.id.to_s})

    assert clusters.any? { |c| c["memories"].map { |m| m["title"] }.include?("Deploy runbook") }
    cluster = clusters.find { |c| c["memories"].any? { |m| m["title"] == "Deploy runbook" } }
    assert_operator cluster["score"], :>=, 0.5
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

  # Calls a tool and returns its parsed JSON result (the value tools return),
  # not the JSON-RPC envelope. Defaults to the read-only token.
  def call_tool(name, arguments, token: @read_token.raw_token)
    result = mcp(rpc("tools/call", name: name, arguments: arguments), token: token)
    JSON.parse(result["result"]["content"].first["text"])
  end
end
