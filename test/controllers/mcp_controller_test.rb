require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  HISTORICAL_VERSION_ERROR =
    "historical versions are immutable — update the current version or create a new version"

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

  test "tools/list advertises relevance sort and the complete search contract" do
    result = mcp(rpc("tools/list"), token: @read_token.raw_token)
    tool = result["result"]["tools"].find { |candidate| candidate["name"] == "list_memories" }
    properties = tool["inputSchema"]["properties"]

    assert_equal %w[relevance updated created title], properties["sort"]["enum"]
    assert_includes properties["sort"]["description"], "Defaults to relevance when query is present"
    assert_includes properties["query"]["description"], "safe exact FTS phrase"
    assert_includes properties["query"]["description"], "case-insensitive whole-tag equality"
    assert_includes properties["query"]["description"],
      "Matching is substring-level (trigram tokenizer)"
    assert_includes properties["query"]["description"], "`rank` matches `ranking`"
    assert_includes properties["query"]["description"], "1–2 characters"
    assert_includes tool["description"], "FTS matches come first by relevance"
    assert_includes tool["description"], "tag-only matches by recency"
  end

  test "tools/list advertises omitted field and blank overwrite update semantics" do
    result = mcp(rpc("tools/list"), token: @read_token.raw_token)
    update_tool = result["result"]["tools"].find { |tool| tool["name"] == "update_memory" }

    assert_includes update_tool["description"], "Omitted fields remain unchanged"
    assert_includes update_tool["description"], "blank content cannot overwrite a non-empty body"
    assert_includes update_tool["description"], "use create_version to preserve history"
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

  test "list_memories defaults to relevance with a query and permits explicit overrides" do
    workspace = @account.workspaces.create!(name: "MCP Search Sort")
    fts = Memory.create_with_content(workspace, title: "Release notes", content: "body")
    tag = Memory.create_with_content(workspace,
      title: "Newest tag", content: "body", tags: ["release notes"])
    fts.update_column(:updated_at, 2.days.ago)
    tag.update_column(:updated_at, 1.hour.from_now)

    relevant = call_tool("list_memories",
      {workspace_id: workspace.id.to_s, query: " release notes "})
    updated = call_tool("list_memories",
      {workspace_id: workspace.id.to_s, query: "release notes", sort: "updated"})

    assert_equal [fts.id.to_s, tag.id.to_s], relevant["memories"].map { |memory| memory["id"] }
    assert_equal [tag.id.to_s, fts.id.to_s], updated["memories"].map { |memory| memory["id"] }
  end

  test "list_memories applies explicit non-relevance sorts and resolves relevance without a query" do
    workspace = @account.workspaces.create!(name: "MCP Explicit Sorts")
    zebra = Memory.create_with_content(workspace, title: "Zebra", content: "body")
    alpha = Memory.create_with_content(workspace, title: "Alpha", content: "body")
    zebra.update_columns(created_at: 2.days.ago, updated_at: 1.hour.from_now)
    alpha.update_columns(created_at: 1.day.ago, updated_at: 2.days.ago)

    title = call_tool("list_memories", {workspace_id: workspace.id.to_s, sort: "title"})
    created = call_tool("list_memories", {workspace_id: workspace.id.to_s, sort: "created"})
    relevance = call_tool("list_memories", {workspace_id: workspace.id.to_s, sort: "relevance"})

    assert_equal [alpha.id.to_s, zebra.id.to_s], title["memories"].map { |memory| memory["id"] }
    assert_equal [alpha.id.to_s, zebra.id.to_s], created["memories"].map { |memory| memory["id"] }
    assert_equal [zebra.id.to_s, alpha.id.to_s], relevance["memories"].map { |memory| memory["id"] }
  end

  test "list_memories accepts short exact-tag queries without invoking FTS" do
    workspace = @account.workspaces.create!(name: "MCP Short Search")
    tag = Memory.create_with_content(workspace, title: "Tagged", content: "body", tags: ["Go"])
    Memory.create_with_content(workspace, title: "Go title only", content: "body")

    payload = call_tool("list_memories", {workspace_id: workspace.id.to_s, query: "go"})

    assert_equal 1, payload["total_count"]
    assert_equal [tag.id.to_s], payload["memories"].map { |memory| memory["id"] }
  end

  test "list_memories relevance pagination is stable with tied tag-only matches" do
    workspace = @account.workspaces.create!(name: "MCP Stable Search")
    memories = 3.times.map do |index|
      Memory.create_with_content(workspace,
        title: "Tag #{index}", content: "body", tags: ["go"])
    end
    tied_at = 1.day.ago
    memories.each { |memory| memory.update_column(:updated_at, tied_at) }

    first = call_tool("list_memories",
      {workspace_id: workspace.id.to_s, query: "go", limit: 2, offset: 0})
    second = call_tool("list_memories",
      {workspace_id: workspace.id.to_s, query: "go", limit: 2, offset: first["next_offset"]})

    assert_equal 3, first["total_count"]
    assert_equal first["total_count"], second["total_count"]
    assert_equal memories.sort_by { |memory| -memory.id }.map { |memory| memory.id.to_s },
      first["memories"].map { |memory| memory["id"] } + second["memories"].map { |memory| memory["id"] }
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

  test "update_memory with a root id targets current and remains visible through read and list" do
    workspace = @account.workspaces.create!(name: "MCP Root Update")
    original_body = "# Version one\n\nKeep these bytes.\n"
    root = Memory.create_with_content(workspace,
      title: "Version one", content: original_body, tags: ["v1"])
    current = root.create_version!(
      title: "Version two", content: "Replace me", tags: ["v2"]
    )
    payload = nil

    assert_no_difference -> { root.all_versions.count } do
      result = mcp(
        rpc("tools/call", name: "update_memory",
          arguments: {
            memory_id: root.id.to_s,
            title: "Updated current",
            content: "# Updated\n\nCurrent body.\n",
            tags: ["current", "edited"]
          }),
        token: @full_token.raw_token
      )
      assert_not result.dig("result", "isError")
      payload = JSON.parse(result.dig("result", "content", 0, "text"))
    end

    assert_equal root.id.to_s, payload["id"]
    assert_equal "Updated current", payload["title"]
    assert_equal ["current", "edited"], payload["tags"]

    current.reload
    assert_equal "Updated current", current.title
    assert_equal "# Updated\n\nCurrent body.\n", current.content.body.content
    assert_equal ["current", "edited"], current.tags
    assert_equal "Version one", root.reload.title
    assert_equal ["v1"], root.tags
    assert_equal original_body.bytes, root.content.body.content.bytes

    read = call_tool("read_memory", {memory_id: root.id.to_s})
    assert_equal root.id.to_s, read["id"]
    assert_equal "Updated current", read["title"]
    assert_equal "# Updated\n\nCurrent body.\n", read["content"]

    listed = call_tool("list_memories",
      {workspace_id: workspace.id.to_s})["memories"].find { |memory| memory["id"] == root.id.to_s }
    assert_equal "Updated current", listed["title"]
    assert_equal ["current", "edited"], listed["tags"]
  end

  test "update_memory rejects a historical child before validation without touching the root" do
    workspace = @account.workspaces.create!(name: "MCP Immutable History")
    root = Memory.create_with_content(workspace,
      title: "Version one", content: "First body", tags: ["v1"], category: "general")
    historical = root.create_version!(
      title: "Version two", content: "Second body", tags: ["v2"], category: "discovery"
    )
    current = root.create_version!(
      title: "Version three", content: "Third body", tags: ["v3"], category: "decision"
    )
    root.update_column(:updated_at, 2.days.ago)
    root_updated_at = root.reload.updated_at
    result = nil

    assert_no_difference -> { root.all_versions.count } do
      result = mcp(
        rpc("tools/call", name: "update_memory",
          arguments: {
            memory_id: historical.id.to_s,
            title: "Corrupted",
            content: "Corrupted body",
            tags: ["corrupted"],
            category: "not-a-category"
          }),
        token: @full_token.raw_token
      )
    end

    assert result.dig("result", "isError")
    assert_equal HISTORICAL_VERSION_ERROR, result.dig("result", "content", 0, "text")

    historical.reload
    assert_equal "Version two", historical.title
    assert_equal "Second body", historical.content.body.content
    assert_equal ["v2"], historical.tags
    assert_equal "discovery", historical.category

    current.reload
    assert_equal "Version three", current.title
    assert_equal "Third body", current.content.body.content
    assert_equal ["v3"], current.tags
    assert_equal "decision", current.category

    root.reload
    assert_equal "Version one", root.title
    assert_equal "First body", root.content.body.content
    assert_equal root_updated_at, root.updated_at
  end

  test "update_memory accepts a current child id and moves its root first in updated order" do
    workspace = @account.workspaces.create!(name: "MCP Current Child Update")
    root = Memory.create_with_content(workspace, title: "Version one", content: "First")
    current = root.create_version!(title: "Version two", content: "Second")
    other = Memory.create_with_content(workspace, title: "Other memory", content: "Other")
    root.update_column(:updated_at, 2.days.ago)
    other.update_column(:updated_at, 1.day.ago)
    root_updated_at = root.reload.updated_at
    payload = nil

    travel_to 1.hour.from_now do
      result = mcp(
        rpc("tools/call", name: "update_memory",
          arguments: {memory_id: current.id.to_s, title: "Direct current update"}),
        token: @full_token.raw_token
      )
      assert_not result.dig("result", "isError")
      payload = JSON.parse(result.dig("result", "content", 0, "text"))
    end

    assert_equal root.id.to_s, payload["id"]
    assert_equal "Direct current update", payload["title"]
    assert_operator root.reload.updated_at, :>, root_updated_at

    listed = call_tool("list_memories",
      {workspace_id: workspace.id.to_s, sort: "updated"})
    assert_equal root.id.to_s, listed["memories"].first["id"]
    assert_equal "Direct current update", listed["memories"].first["title"]
  end

  test "update_memory root id blank guard checks current body and touches nothing" do
    workspace = @account.workspaces.create!(name: "MCP Current Blank Guard")
    root = Memory.create_with_content(workspace, title: "Blank v1", content: "")
    current = root.create_version!(title: "Nonblank v2", content: "Existing current body")
    root.update_column(:updated_at, 2.days.ago)
    current.update_column(:updated_at, 1.day.ago)
    root_updated_at = root.reload.updated_at
    current_updated_at = current.reload.updated_at

    assert_no_difference -> { root.all_versions.count } do
      result = mcp(
        rpc("tools/call", name: "update_memory",
          arguments: {memory_id: root.id.to_s, title: "Must roll back", content: ""}),
        token: @full_token.raw_token
      )

      assert result.dig("result", "isError")
      assert_includes result.dig("result", "content", 0, "text"),
        I18n.t("activerecord.errors.models.memory.attributes.content.blank_overwrite")
    end

    assert_equal "Blank v1", root.reload.title
    assert_equal "", root.content.body.content
    assert_equal root_updated_at, root.updated_at
    assert_equal "Nonblank v2", current.reload.title
    assert_equal "Existing current body", current.content.body.content
    assert_equal current_updated_at, current.updated_at
  end

  test "update_memory preserves multiline content when content is omitted" do
    body = "# Exact Markdown\n\n- one\n- two\n\nTrailing line\n"
    memory = Memory.create_with_content(@workspace, title: "Keep body", content: body)

    result = mcp(
      rpc("tools/call", name: "update_memory",
        arguments: {memory_id: memory.id.to_s, tags: ["edited"]}),
      token: @full_token.raw_token
    )

    assert_not result.dig("result", "isError")
    assert_equal ["edited"], memory.reload.tags
    assert_equal body, memory.content.body.content
  end

  test "update_memory surfaces blank content overwrite as a tool error" do
    memory = Memory.create_with_content(@workspace, title: "Before", content: "Existing body")

    result = mcp(
      rpc("tools/call", name: "update_memory",
        arguments: {memory_id: memory.id.to_s, title: "After", content: ""}),
      token: @full_token.raw_token
    )

    assert result.dig("result", "isError")
    assert_includes result.dig("result", "content", 0, "text"),
      I18n.t("activerecord.errors.models.memory.attributes.content.blank_overwrite")
    assert_equal "Before", memory.reload.title
    assert_equal "Existing body", memory.content.body.content
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
