require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  HISTORICAL_VERSION_ERROR =
    "historical versions are immutable — update the current version or create a new version"
  LIST_MEMORIES_DESCRIPTION = "List memories within a workspace. Search runs FTS across title " \
    "and body (same query language as web and REST search) and also matches case-insensitive " \
    "whole tags. " \
    "FTS matches come first by relevance, followed by tag-only matches by recency; " \
    "a memory matching both appears once as an FTS match. Queries under 3 characters " \
    "search exact tags only. When a search finds fewer than 3 matches, up to 5 memories " \
    "close in meaning follow on the first page, marked match: \"related\" with a similarity " \
    "(keyword hits are match: \"keyword\"); they don't contain the query words. " \
    "Returns a paginated envelope: " \
    "{memories, total_count, has_more, next_offset}, plus related_count when searching; " \
    "total_count counts keyword matches only. Pass `offset: next_offset` " \
    "to fetch the following page. Defaults to 50 per page (max 200). " \
    "Memories tagged obsolete, superseded or deprecated are excluded by default; " \
    "pass include: [\"obsolete\"] to retrieve them."

  setup do
    @user = users(:one)
    @account = @user.account
    @workspace = workspaces(:one)
    @client = OauthClient.create!(client_name: "Claude", redirect_uris: JSON.generate(["https://claude.ai/cb"]))

    @full_token = oauth_token(permission: "full_access", scope: "memories:read memories:write")
    @read_token = oauth_token(permission: "read_only", scope: "memories:read")
  end

  test "rejects requests without a Bearer token" do
    mcp_post(mcp_rpc("tools/list"))
    assert_response :unauthorized
    assert_match "resource_metadata", response.headers["WWW-Authenticate"]
    assert_includes response.headers["WWW-Authenticate"], 'scope="memories:read"'
    assert_equal(-32_001, JSON.parse(response.body)["error"]["code"])
  end

  test "rejects an expired token" do
    expired = oauth_token(permission: "read_only", scope: "memories:read", expires_at: 1.hour.ago)
    result = mcp_post(mcp_rpc("tools/list"), token: expired.raw_token)
    assert_response :unauthorized
    assert_nil result["result"]
  end

  test "tools/list returns every defined tool" do
    result = mcp_post(mcp_rpc("tools/list"), token: @read_token.raw_token)
    tools = result["result"]["tools"]
    names = tools.map { |t| t["name"] }
    assert_equal 13, names.size
    assert_equal "workspace_context", names.first
    assert_equal Mcp::ToolDefinitions::NAMES.sort, names.sort
    assert_includes names, "create_version"
    assert_includes names, "read_memories"
    assert_includes names, "link_memories"
    assert_includes names, "workspace_stats"
    assert_includes names, "suggest_merge_candidates"
    workspace_context = tools.find { |tool| tool["name"] == "workspace_context" }
    assert workspace_context["description"].end_with?(
      "Call this before searching or writing, so later work is informed by what the " \
        "workspace already holds and does not duplicate it. " \
        "Memories tagged obsolete, superseded or deprecated are excluded by default; " \
        "pass include: [\"obsolete\"] to retrieve them."
    )
  end

  test "tools/list appends the write mechanics descriptions" do
    result = mcp_post(mcp_rpc("tools/list"), token: @read_token.raw_token)
    tools = result["result"]["tools"].index_by { |tool| tool["name"] }

    assert_includes tools["create_memory"]["description"],
      "Mechanics: creates a new root memory at version 1."
    assert_includes tools["update_memory"]["description"],
      "Mechanics: edits the current version in place and does not add a history entry."
    assert_includes tools["create_version"]["description"],
      "Mechanics: appends a new current version and leaves earlier versions intact."
  end

  test "create_version refuses a repeat end to end, despite the source it stamps" do
    token = oauth_token(permission: "full_access", scope: "memories:read memories:write").raw_token
    memory = Memory.create_with_content(@workspace, title: "Repeat", content: "v1", source: "manual", created_by: users(:one))
    memory.create_version!(content: "latest", source: "manual")

    assert_no_difference("Memory.count") do
      [
        {"memory_id" => memory.id.to_s},
        {"memory_id" => memory.id.to_s, "content" => "latest"},
        {"memory_id" => memory.id.to_s, "change_note" => "Only a note"}
      ].each do |arguments|
        result = mcp_post(mcp_rpc("tools/call", name: "create_version", arguments: arguments), token: token)
        assert result.dig("result", "isError"), arguments.inspect
        assert_match "Nothing has changed", result.dig("result", "content", 0, "text")
      end
    end

    assert_difference("Memory.count", 1) do
      result = mcp_post(mcp_rpc("tools/call", name: "create_version",
        arguments: {"memory_id" => memory.id.to_s, "content" => "new"}), token: token)
      assert_not result.dig("result", "isError")
      assert_equal "new", memory.reload.current_version.content.body.content
    end
  end

  test "tools/list advertises tags and category inputs on write tools" do
    result = mcp_post(mcp_rpc("tools/list"), token: @read_token.raw_token)
    tools = result["result"]["tools"].index_by { |t| t["name"] }

    create_props = tools["create_memory"]["inputSchema"]["properties"]
    assert_equal "array", create_props["tags"]["type"]

    update_props = tools["update_memory"]["inputSchema"]["properties"]
    assert_equal "array", update_props["tags"]["type"]
    assert_equal Mcp::ToolDefinitions::CATEGORIES, update_props["category"]["enum"]
  end

  test "tools/list advertises relevance sort and the complete search contract" do
    result = mcp_post(mcp_rpc("tools/list"), token: @read_token.raw_token)
    tool = result["result"]["tools"].find { |candidate| candidate["name"] == "list_memories" }
    properties = tool["inputSchema"]["properties"]

    assert_equal %w[relevance updated created title], properties["sort"]["enum"]
    assert_includes properties["sort"]["description"], "Defaults to relevance when query is present"
    assert_includes properties["query"]["description"], "Words are ANDed"
    assert_includes properties["query"]["description"], "never an error"
    assert_includes properties["query"]["description"], "case-insensitive whole-tag equality"
    assert_includes properties["query"]["description"],
      "Matching is substring-level (trigram tokenizer)"
    assert_includes properties["query"]["description"], "`rank` matches `ranking`"
    assert_includes properties["query"]["description"], "1–2 characters"
    assert_includes tool["description"], "FTS matches come first by relevance"
    assert_includes tool["description"], "tag-only matches by recency"
    assert_equal LIST_MEMORIES_DESCRIPTION, tool["description"]
    assert_equal %w[lexical semantic], properties["retrieval"]["enum"]
    assert_includes properties["retrieval"]["description"], "lexical: keyword matches only"
    assert_includes properties["retrieval"]["description"], "Requires server flag"
  end

  test "tools/list advertises omitted field and blank overwrite update semantics" do
    result = mcp_post(mcp_rpc("tools/list"), token: @read_token.raw_token)
    update_tool = result["result"]["tools"].find { |tool| tool["name"] == "update_memory" }

    assert_includes update_tool["description"], "Omitted fields remain unchanged"
    assert_includes update_tool["description"], "blank content cannot overwrite a non-empty body"
    assert_includes update_tool["description"], "use create_version to preserve history"
  end

  test "list_workspaces returns the account's workspaces" do
    result = mcp_post(mcp_rpc("tools/call", name: "list_workspaces"), token: @read_token.raw_token)
    payload = JSON.parse(result["result"]["content"].first["text"])
    assert_includes payload.map { |w| w["name"] }, @workspace.name
  end

  test "workspace_context returns pinned current-version bodies through read_only access" do
    workspace = create_workspace_without_starter_map("MCP pinned context")
    root = Memory.create_with_content(
      workspace,
      title: "Version one",
      content: "First body",
      category: "general"
    )
    root.create_version!(
      title: "Version two",
      content: "Second body",
      category: "discovery"
    )
    current = root.create_version!(
      title: "Version three",
      content: "Third body",
      category: "decision",
      tags: ["latest"],
      source: "manual"
    )
    root.pin!(@user)

    payload = call_tool("workspace_context", {workspace_id: workspace.id.to_s})

    assert_equal %w[context_source generated_at memories stats workspace], payload.keys.sort
    assert_equal "pins", payload["context_source"]
    assert_equal 1, payload.dig("stats", "total_pinned")
    assert_equal 1, payload.dig("stats", "returned")
    assert Time.iso8601(payload["generated_at"])

    memory = payload["memories"].sole
    assert_equal root.id.to_s, memory["id"]
    assert_equal current.title, memory["title"]
    assert_equal current.content.body.content, memory["body"]
    assert_equal current.category, memory["category"]
    assert_equal current.tags, memory["tags"]
    assert_equal current.version, memory["version"]
    assert_equal false, memory["body_truncated"]
    assert_empty memory.keys & %w[url links_count pinned_at pinned_memories]
  end

  test "workspace_context falls back to recent roots and supports body options and clamping" do
    workspace = create_workspace_without_starter_map("MCP recent context")
    older = Memory.create_with_content(workspace, title: "Older", content: "old")
    newer_body = "x" * 300
    newer = Memory.create_with_content(workspace, title: "Newer", content: newer_body)
    older.update_column(:updated_at, 2.days.ago)
    newer.update_column(:updated_at, 1.day.ago)

    payload = call_tool(
      "workspace_context",
      {
        workspace_id: workspace.id.to_s,
        limit: 1,
        max_body_chars: 1
      }
    )

    assert_equal "recent", payload["context_source"]
    assert_equal 0, payload.dig("stats", "total_pinned")
    assert_equal [newer.id.to_s], payload["memories"].map { |memory| memory["id"] }
    assert_equal 100, payload["memories"].first["body"].length
    assert_equal true, payload["memories"].first["body_truncated"]

    without_body = call_tool(
      "workspace_context",
      {workspace_id: workspace.id.to_s, include_body: false}
    )
    assert without_body["memories"].none? { |memory| memory.key?("body") }
    assert without_body["memories"].none? { |memory| memory.key?("body_truncated") }
  end

  test "workspace_context validates category and account-scopes active workspaces" do
    invalid = mcp_post(
      mcp_rpc(
        "tools/call",
        name: "workspace_context",
        arguments: {workspace_id: @workspace.id.to_s, category: "bogus"}
      ),
      token: @read_token.raw_token
    )
    assert invalid.dig("result", "isError")
    assert_match "Invalid category", invalid.dig("result", "content", 0, "text")

    foreign = mcp_post(
      mcp_rpc(
        "tools/call",
        name: "workspace_context",
        arguments: {workspace_id: workspaces(:two).id.to_s}
      ),
      token: @read_token.raw_token
    )
    assert foreign.dig("result", "isError")
    assert_equal "Workspace not found", foreign.dig("result", "content", 0, "text")
  end

  test "workspace_context root id matches list and updates directly with REST parity" do
    workspace = create_workspace_without_starter_map("MCP parity")
    root = Memory.create_with_content(workspace, title: "V1", content: "Body v1")
    root.create_version!(title: "V2", content: "Body v2")
    current = root.create_version!(title: "V3", content: "Body v3", tags: ["v3"])
    root.pin!(@user)

    context = call_tool("workspace_context", {workspace_id: workspace.id.to_s})
    mcp_memory = context["memories"].sole
    listed = call_tool("list_memories", {workspace_id: workspace.id.to_s})
      .fetch("memories")
      .sole

    get workspace_context_url(workspace, format: :json),
      headers: auth_headers(@read_token.raw_token)
    assert_response :success
    rest_memory = JSON.parse(response.body)["memories"].sole

    assert_equal root.id.to_s, mcp_memory["id"]
    assert_equal listed["id"], mcp_memory["id"]
    assert_equal current.title, mcp_memory["title"]
    assert_equal rest_memory.values_at("title", "body"),
      mcp_memory.values_at("title", "body")

    updated = call_tool(
      "update_memory",
      {memory_id: mcp_memory["id"], title: "Updated through context ID"},
      token: @full_token.raw_token
    )
    assert_equal root.id.to_s, updated["id"]
    assert_equal "Updated through context ID", current.reload.title
  end

  test "create_memory is denied for a read_only token" do
    result = mcp_post(
      mcp_rpc("tools/call", name: "create_memory",
        arguments: {workspace_id: @workspace.id.to_s, title: "X", content: "Y"}),
      token: @read_token.raw_token
    )
    assert_insufficient_scope(result)
  end

  test "create_memory persists tags and stamps source with the client name" do
    result = nil
    assert_difference -> { @workspace.memories.count }, 1 do
      result = mcp_post(
        mcp_rpc("tools/call", name: "create_memory",
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
    result = mcp_post(
      mcp_rpc("tools/call", name: "create_memory",
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

    result = mcp_post(
      mcp_rpc("tools/call", name: "read_memory", arguments: {memory_id: memory.id.to_s}),
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
    workspace = create_workspace_without_starter_map("MCP Search Sort")
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

  test "hybrid flag and omitted retrieval preserve the complete lexical contract" do
    workspace = create_workspace_without_starter_map("MCP Hybrid Lexical Regression")
    fts = Memory.create_with_content(
      workspace,
      title: "Checkpoint runbook",
      content: "checkpoint checkpoint recovery"
    )
    dual = Memory.create_with_content(
      workspace,
      title: "Checkpoint notes",
      content: "checkpoint",
      tags: ["checkpoint"]
    )
    tag_only = Memory.create_with_content(
      workspace,
      title: "Storage operations",
      content: "mount details",
      tags: ["checkpoint"]
    )
    tag_only.update_column(:updated_at, 1.hour.from_now)

    args = {workspace_id: workspace.id.to_s, query: "checkpoint"}
    lexical_ids = nil
    flag_off = nil
    with_hybrid_retrieval(false) do
      lexical_ids = workspace.memories.latest_versions.search("checkpoint").pluck(:id)
      flag_off = call_tool("list_memories", args)
    end

    assert_equal [fts.id, dual.id].sort, lexical_ids.first(2).sort
    assert_equal tag_only.id, lexical_ids.last
    assert_equal lexical_ids.map(&:to_s), flag_off["memories"].map { |memory| memory["id"] }

    with_hybrid_retrieval(true) do
      assert_equal lexical_ids,
        workspace.memories.latest_versions.search("checkpoint").pluck(:id)
      assert_equal flag_off, call_tool("list_memories", args)
      assert_equal flag_off, call_tool("list_memories", args.merge(retrieval: "lexical"))
    end

    embedding_sql = []
    subscriber = lambda do |_name, _started, _finished, _id, payload|
      embedding_sql << payload[:sql] if payload[:sql].match?(/memory_embeddings/i)
    end
    with_hybrid_retrieval(false) do
      ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
        %w[semantic hybrid hybrid_decay invalid].each do |retrieval|
          assert_equal flag_off,
            call_tool("list_memories", args.merge(retrieval: retrieval)),
            retrieval
        end
      end
    end
    assert_empty embedding_sql
  end

  test "enabled retrieval validation rejects explicit null blank and unknown modes" do
    with_hybrid_retrieval(true) do
      [nil, "", "unknown", "hybrid", "hybrid_decay"].each do |retrieval|
        result = mcp_post(
          mcp_rpc(
            "tools/call",
            name: "list_memories",
            arguments: {workspace_id: @workspace.id.to_s, retrieval: retrieval}
          ),
          token: @read_token.raw_token
        )

        assert result.dig("result", "isError"), retrieval.inspect
        assert_equal "Invalid retrieval mode", result.dig("result", "content", 0, "text")
      end
    end
  end

  test "short and blank experimental queries stay lexical and never invoke the provider" do
    workspace = create_workspace_without_starter_map("MCP Short Experimental")
    tag = Memory.create_with_content(workspace, title: "Tagged", content: "body", tags: ["Go"])
    other = Memory.create_with_content(workspace, title: "Other", content: "body")
    provider = FakeEmbeddingProvider.new

    with_hybrid_retrieval(provider: provider) do
      short = call_tool(
        "list_memories",
        {workspace_id: workspace.id.to_s, query: "go", retrieval: "semantic"}
      )
      blank = call_tool(
        "list_memories",
        {workspace_id: workspace.id.to_s, query: "  ", retrieval: "semantic"}
      )

      assert_equal [tag.id.to_s], short["memories"].map { |memory| memory["id"] }
      assert_equal [other.id.to_s, tag.id.to_s],
        blank["memories"].map { |memory| memory["id"] }
    end

    assert_empty provider.embedded_texts
  end

  test "semantic retrieval preserves rank while explicit sorts override it" do
    workspace = create_workspace_without_starter_map("MCP Semantic Sorts")
    alpha = Memory.create_with_content(workspace, title: "Alpha", content: "body")
    beta = Memory.create_with_content(workspace, title: "Beta", content: "body")
    gamma = Memory.create_with_content(workspace, title: "Gamma", content: "body")
    alpha.update_columns(created_at: 3.days.ago, updated_at: 1.day.ago)
    beta.update_columns(created_at: 1.day.ago, updated_at: 3.days.ago)
    gamma.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)
    query = "restore hangs"
    provider = FakeEmbeddingProvider.new(vectors: {query => [1.0, 0.0, 0.0]})
    create_memory_embedding(alpha, vector: [0.5, 0.5, 0.0], model: provider.model)
    create_memory_embedding(beta, vector: [1.0, 0.0, 0.0], model: provider.model)
    create_memory_embedding(gamma, vector: [0.8, 0.2, 0.0], model: provider.model)
    base_args = {workspace_id: workspace.id.to_s, query: query, retrieval: "semantic"}

    with_hybrid_retrieval(provider: provider) do
      relevance = call_tool("list_memories", base_args.merge(limit: 2))
      title = call_tool("list_memories", base_args.merge(sort: "title"))
      updated = call_tool("list_memories", base_args.merge(sort: "updated"))
      created = call_tool("list_memories", base_args.merge(sort: "created"))

      assert_equal [beta.id.to_s, gamma.id.to_s],
        relevance["memories"].map { |memory| memory["id"] }
      assert_equal 3, relevance["total_count"]
      assert relevance["has_more"]
      assert_equal 2, relevance["next_offset"]
      assert_equal [alpha.id.to_s, beta.id.to_s, gamma.id.to_s],
        title["memories"].map { |memory| memory["id"] }
      assert_equal [alpha.id.to_s, gamma.id.to_s, beta.id.to_s],
        updated["memories"].map { |memory| memory["id"] }
      assert_equal [beta.id.to_s, gamma.id.to_s, alpha.id.to_s],
        created["memories"].map { |memory| memory["id"] }
    end

    assert_equal [query] * 4, provider.embedded_texts
  end

  test "semantic category filtering happens after the top fifty are ranked" do
    workspace = create_workspace_without_starter_map("MCP Semantic Category")
    query = "restore hangs"
    provider = FakeEmbeddingProvider.new(vectors: {query => [1.0, 0.0, 0.0]})

    50.times do |index|
      memory = Memory.create_with_content(
        workspace,
        title: "General #{index}",
        content: "body",
        category: "general"
      )
      create_memory_embedding(
        memory,
        vector: [1.0, (index + 1) / 100.0, 0.0],
        model: provider.model
      )
    end
    decision = Memory.create_with_content(
      workspace,
      title: "Decision below cutoff",
      content: "body",
      category: "decision"
    )
    create_memory_embedding(decision, vector: [0.0, 1.0, 0.0], model: provider.model)

    with_hybrid_retrieval(provider: provider) do
      payload = call_tool(
        "list_memories",
        {
          workspace_id: workspace.id.to_s,
          query: query,
          retrieval: "semantic",
          category: "decision"
        }
      )

      assert_equal 0, payload["total_count"]
      assert_empty payload["memories"]
    end
  end

  test "semantic provider load failures return a backfill tool error without fallback" do
    provider = FakeEmbeddingProvider.new do
      raise EmbeddingProviders::Error, "model cache missing"
    end

    with_hybrid_retrieval(provider: provider) do
      result = mcp_post(
        mcp_rpc(
          "tools/call",
          name: "list_memories",
          arguments: {
            workspace_id: @workspace.id.to_s,
            query: "restore hangs",
            retrieval: "semantic"
          }
        ),
        token: @read_token.raw_token
      )

      assert result.dig("result", "isError")
      assert_includes result.dig("result", "content", 0, "text"), "search:embed_backfill"
      assert_not_includes result.dig("result", "content", 0, "text"), "model cache missing"
    end
  end

  test "list_memories applies explicit non-relevance sorts and resolves relevance without a query" do
    workspace = create_workspace_without_starter_map("MCP Explicit Sorts")
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

  test "list_memories updated sort reflects version creation" do
    workspace = create_workspace_without_starter_map("MCP Version Sort")
    versioned = Memory.create_with_content(workspace, title: "Versioned", content: "v1")
    other = Memory.create_with_content(workspace, title: "Other", content: "body")
    versioned.update_column(:updated_at, 2.days.ago)
    other.update_column(:updated_at, 1.day.ago)

    travel_to Time.current do
      call_tool(
        "create_version",
        {memory_id: versioned.id.to_s, title: "Versioned current", content: "v2"},
        token: @full_token.raw_token
      )
    end

    listed = call_tool("list_memories", {workspace_id: workspace.id.to_s, sort: "updated"})

    assert_equal [versioned.id.to_s, other.id.to_s],
      listed["memories"].map { |memory| memory["id"] }
  end

  test "list_memories accepts short exact-tag queries without invoking FTS" do
    workspace = create_workspace_without_starter_map("MCP Short Search")
    tag = Memory.create_with_content(workspace, title: "Tagged", content: "body", tags: ["Go"])
    Memory.create_with_content(workspace, title: "Go title only", content: "body")

    payload = call_tool("list_memories", {workspace_id: workspace.id.to_s, query: "go"})

    assert_equal 1, payload["total_count"]
    assert_equal [tag.id.to_s], payload["memories"].map { |memory| memory["id"] }
  end

  test "list_memories relevance pagination is stable with tied tag-only matches" do
    workspace = create_workspace_without_starter_map("MCP Stable Search")
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
    result = mcp_post(
      mcp_rpc("tools/call", name: "list_memories",
        arguments: {workspace_id: @workspace.id.to_s, category: "bogus"}),
      token: @read_token.raw_token
    )
    assert result["result"]["isError"]
    assert_match "Invalid category", result["result"]["content"].first["text"]
  end

  # --- obsolete filtering ---------------------------------------------------

  test "list_memories hides obsolete memories unless include is passed" do
    Memory.create_with_content(@workspace, title: "Retired plan", content: "b", tags: ["Superseded"])
    Memory.create_with_content(@workspace, title: "Current plan", content: "b")

    default = call_tool("list_memories", {workspace_id: @workspace.id.to_s})
    titles = default["memories"].map { |m| m["title"] }
    refute_includes titles, "Retired plan"
    assert_includes titles, "Current plan"

    included = call_tool("list_memories", {workspace_id: @workspace.id.to_s, include: ["obsolete"]})
    assert_includes included["memories"].map { |m| m["title"] }, "Retired plan"
    assert_equal default["total_count"] + 1, included["total_count"]
  end

  test "workspace_context hides obsolete memories unless include is passed" do
    Pin.destroy_all # exercise the recent branch, not the pinned one
    Memory.create_with_content(@workspace, title: "Retired context", content: "b", tags: ["obsolete"])

    default = call_tool("workspace_context", {workspace_id: @workspace.id.to_s, limit: 50})
    refute_includes default["memories"].map { |m| m["title"] }, "Retired context"

    included = call_tool("workspace_context",
      {workspace_id: @workspace.id.to_s, limit: 50, include: ["obsolete"]})
    assert_includes included["memories"].map { |m| m["title"] }, "Retired context"
  end

  # --- deleted workspaces ---------------------------------------------------

  test "read_memory refuses a memory in a soft-deleted workspace" do
    memory = Memory.create_with_content(workspaces(:deleted), title: "Gone", content: "body")

    result = mcp_post(
      mcp_rpc("tools/call", name: "read_memory", arguments: {memory_id: memory.id.to_s}),
      token: @read_token.raw_token
    )

    assert result["result"]["isError"]
    assert_equal "Memory not found", result["result"]["content"].first["text"]
  end

  test "read_memories lists deleted-workspace ids under missing" do
    live = Memory.create_with_content(@workspace, title: "Live", content: "body")
    gone = Memory.create_with_content(workspaces(:deleted), title: "Gone", content: "body")

    payload = call_tool("read_memories", {memory_ids: [live.id.to_s, gone.id.to_s]})

    assert_equal ["Live"], payload["memories"].map { |m| m["title"] }
    assert_equal [gone.id.to_s], payload["missing"]
  end

  test "an archived workspace's memory can't be written to" do
    owner = @read_token.user
    workspace = owner.account.workspaces.create!(name: "To archive", created_by: owner)
    memory = Memory.create_with_content(workspace, title: "Frozen", content: "body", created_by: owner)
    workspace.archive

    assert_no_difference("Memory.count") do
      %w[update_memory create_version].each do |tool|
        error = assert_raises(Mcp::ToolError) do
          Mcp::Tools.public_send(tool, owner.account, {"memory_id" => memory.id.to_s, "title" => "Changed"}, user: owner)
        end
        assert_match(/archived/, error.message)
      end
    end

    assert_equal "Frozen", memory.reload.title
    assert_equal "Frozen", Mcp::Tools.read_memory(owner.account, {"memory_id" => memory.id.to_s}, user: owner)[:title]
  end

  test "an archived workspace's memory stays readable by id" do
    memory = Memory.create_with_content(workspaces(:archived), title: "Old", content: "body")

    payload = call_tool("read_memory", {memory_id: memory.id.to_s})

    assert_equal "Old", payload["title"]
  end

  test "links and updates refuse deleted-workspace memories" do
    live = Memory.create_with_content(@workspace, title: "Live", content: "body")
    gone = Memory.create_with_content(workspaces(:deleted), title: "Gone", content: "body")
    write_token = oauth_token(permission: "full_access", scope: "memories:read memories:write")

    [
      ["list_memory_links", {memory_id: gone.id.to_s}],
      ["link_memories", {memory_id: live.id.to_s, to_memory_id: gone.id.to_s}],
      ["unlink_memories", {memory_id: live.id.to_s, to_memory_id: gone.id.to_s}],
      ["update_memory", {memory_id: gone.id.to_s, content: "edited"}]
    ].each do |name, arguments|
      result = mcp_post(mcp_rpc("tools/call", name: name, arguments: arguments), token: write_token.raw_token)

      assert result["result"]["isError"], name
      assert_equal "Memory not found", result["result"]["content"].first["text"], name
    end
  end

  test "the inactive token stays REST-only" do
    result = mcp_post(
      mcp_rpc("tools/call", name: "list_memories",
        arguments: {workspace_id: @workspace.id.to_s, include: ["inactive"]}),
      token: @read_token.raw_token
    )

    assert result["result"]["isError"]
    assert_match "Invalid include token", result["result"]["content"].first["text"]
  end

  test "memory_json states obsolete and current" do
    root = Memory.create_with_content(@workspace, title: "First", content: "v1")
    root.create_version!(content: "v2")
    retired = Memory.create_with_content(@workspace, title: "Retired", content: "body", tags: ["obsolete"])

    live = call_tool("read_memory", {memory_id: root.id.to_s})
    assert_equal false, live["obsolete"]
    assert_equal true, live["current"]

    payload = call_tool("read_memory", {memory_id: retired.id.to_s})
    assert_equal true, payload["obsolete"]
    assert_equal true, payload["current"]
  end

  test "list_memories search appends related memories unless retrieval is lexical" do
    provider = FakeEmbeddingProvider.new(vectors: {"restore hangs" => [1.0, 0.0, 0.0]})
    related = Memory.create_with_content(@workspace, title: "Checkpoint stalls", content: "Snapshot waits")
    create_memory_embedding(related, vector: [1.0, 0.0, 0.0], model: provider.model)
    query = {workspace_id: @workspace.id.to_s, query: "restore hangs"}

    with_hybrid_retrieval(provider: provider) do
      payload = call_tool("list_memories", query)
      assert_equal 0, payload["total_count"]
      assert_equal 1, payload["related_count"]
      assert_equal [related.id.to_s, "related", 1.0],
        payload["memories"].sole.values_at("id", "match", "similarity")

      assert_empty call_tool("list_memories", query.merge(retrieval: "lexical"))["memories"]
      assert_empty call_tool("list_memories", query.merge(offset: 1))["memories"]
    end
  end

  test "an unadvertised include token is a JSON-RPC error" do
    result = mcp_post(
      mcp_rpc("tools/call", name: "list_memories",
        arguments: {workspace_id: @workspace.id.to_s, include: ["nope"]}),
      token: @read_token.raw_token
    )
    assert result["result"]["isError"]
    assert_match "Invalid include token", result["result"]["content"].first["text"]
  end

  test "include must be an array, not a bare string" do
    result = mcp_post(
      mcp_rpc("tools/call", name: "list_memories",
        arguments: {workspace_id: @workspace.id.to_s, include: "obsolete"}),
      token: @read_token.raw_token
    )
    assert result["result"]["isError"]
    assert_match "Invalid include token", result["result"]["content"].first["text"]
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
    result = mcp_post(
      mcp_rpc("tools/call", name: "link_memories",
        arguments: {memory_id: a.id.to_s, to_memory_id: b.id.to_s}),
      token: @read_token.raw_token
    )
    assert_insufficient_scope(result)
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
      result = mcp_post(
        mcp_rpc("tools/call", name: "update_memory",
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
    workspace = create_workspace_without_starter_map("MCP Root Update")
    original_body = "# Version one\n\nKeep these bytes.\n"
    root = Memory.create_with_content(workspace,
      title: "Version one", content: original_body, tags: ["v1"])
    current = root.create_version!(
      title: "Version two", content: "Replace me", tags: ["v2"]
    )
    payload = nil

    assert_no_difference -> { root.all_versions.count } do
      result = mcp_post(
        mcp_rpc("tools/call", name: "update_memory",
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
    assert_equal ["current", "edited"], root.tags
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
    workspace = create_workspace_without_starter_map("MCP Immutable History")
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
      result = mcp_post(
        mcp_rpc("tools/call", name: "update_memory",
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
    workspace = create_workspace_without_starter_map("MCP Current Child Update")
    root = Memory.create_with_content(workspace, title: "Version one", content: "First")
    current = root.create_version!(title: "Version two", content: "Second")
    other = Memory.create_with_content(workspace, title: "Other memory", content: "Other")
    root.update_column(:updated_at, 2.days.ago)
    other.update_column(:updated_at, 1.day.ago)
    root_updated_at = root.reload.updated_at
    payload = nil

    travel_to 30.minutes.from_now do
      result = mcp_post(
        mcp_rpc("tools/call", name: "update_memory",
          arguments: {memory_id: current.id.to_s, title: "Direct current update"}),
        token: @full_token.raw_token
      )
      assert_response :success
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
    workspace = create_workspace_without_starter_map("MCP Current Blank Guard")
    root = Memory.create_with_content(workspace, title: "Blank v1", content: "")
    current = root.create_version!(title: "Nonblank v2", content: "Existing current body")
    root.update_column(:updated_at, 2.days.ago)
    current.update_column(:updated_at, 1.day.ago)
    root_updated_at = root.reload.updated_at
    current_updated_at = current.reload.updated_at

    assert_no_difference -> { root.all_versions.count } do
      result = mcp_post(
        mcp_rpc("tools/call", name: "update_memory",
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

    result = mcp_post(
      mcp_rpc("tools/call", name: "update_memory",
        arguments: {memory_id: memory.id.to_s, tags: ["edited"]}),
      token: @full_token.raw_token
    )

    assert_not result.dig("result", "isError")
    assert_equal ["edited"], memory.reload.tags
    assert_equal body, memory.content.body.content
  end

  test "update_memory surfaces blank content overwrite as a tool error" do
    memory = Memory.create_with_content(@workspace, title: "Before", content: "Existing body")

    result = mcp_post(
      mcp_rpc("tools/call", name: "update_memory",
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
      result = mcp_post(
        mcp_rpc("tools/call", name: "create_version",
          arguments: {memory_id: memory.id.to_s, content: "Second", tags: ["v2"]}),
        token: @full_token.raw_token
      )
      payload = JSON.parse(result["result"]["content"].first["text"])
      assert_equal "Claude", payload["source"]
      assert_equal ["v2"], payload["tags"]
    end

    read = mcp_post(
      mcp_rpc("tools/call", name: "read_memory", arguments: {memory_id: memory.id.to_s}),
      token: @read_token.raw_token
    )
    read_payload = JSON.parse(read["result"]["content"].first["text"])
    assert_equal "Second", read_payload["content"]
    assert_equal 2, read_payload["version"]
  end

  test "create_version is denied for a read_only token" do
    memory = Memory.create_with_content(@workspace, title: "v1", content: "First")
    result = mcp_post(
      mcp_rpc("tools/call", name: "create_version",
        arguments: {memory_id: memory.id.to_s, content: "Second"}),
      token: @read_token.raw_token
    )
    assert_insufficient_scope(result)
  end

  test "tools enforce account isolation" do
    other_memory = memories(:two) # belongs to account two
    result = mcp_post(
      mcp_rpc("tools/call", name: "read_memory", arguments: {memory_id: other_memory.id.to_s}),
      token: @full_token.raw_token
    )
    assert result["result"]["isError"]
    assert_equal "Memory not found", result["result"]["content"].first["text"]
  end

  # --- Cross-account isolation ----------------------------------------------
  #
  # An MCP token is account-wide by design, so the boundary that matters is the
  # account one. Every tool below is called by account two against account one's
  # ids and must report the record as simply absent — the same answer a made-up
  # id gets, so the error cannot be used to enumerate another account.

  test "workspace tools cannot reach another account's workspace" do
    foreign_workspace = workspaces(:one)

    %w[workspace_context list_memories workspace_stats suggest_merge_candidates].each do |tool|
      assert_tool_error "Workspace not found",
        tool, {"workspace_id" => foreign_workspace.id.to_s}, token: foreign_account_token
    end

    assert_no_difference "Memory.count" do
      assert_tool_error "Workspace not found", "create_memory",
        {"workspace_id" => foreign_workspace.id.to_s, "title" => "Injected", "content" => "hello"},
        token: foreign_account_token
    end
  end

  test "memory tools cannot reach another account's memory" do
    foreign_memory = memories(:one)
    own_memory = memories(:two)
    attributes = foreign_memory.attributes

    single = {"memory_id" => foreign_memory.id.to_s}
    paired = single.merge("to_memory_id" => own_memory.id.to_s)

    assert_no_difference ["Memory.count", "MemoryLink.count"] do
      assert_tool_error "Memory not found", "read_memory", single, token: foreign_account_token
      assert_tool_error "Memory not found", "update_memory", single.merge("title" => "Hijacked"), token: foreign_account_token
      assert_tool_error "Memory not found", "create_version", single.merge("content" => "hijacked"), token: foreign_account_token
      assert_tool_error "Memory not found", "list_memory_links", single, token: foreign_account_token
      assert_tool_error "Memory not found", "link_memories", paired, token: foreign_account_token
      assert_tool_error "Memory not found", "unlink_memories", paired, token: foreign_account_token
    end

    assert_equal attributes, foreign_memory.reload.attributes
  end

  test "read_memories reports another account's ids as missing rather than reading them" do
    foreign_memory = memories(:one)

    result = call_tool("read_memories", {"memory_ids" => [foreign_memory.id.to_s]}, token: foreign_account_token)

    assert_empty result["memories"]
    assert_equal [foreign_memory.id.to_s], result["missing"]
  end

  test "list_workspaces never includes another account's workspace" do
    result = call_tool("list_workspaces", {}, token: foreign_account_token)

    ids = Array(result).map { |workspace| workspace["id"].to_s }
    assert_not_includes ids, workspaces(:one).id.to_s
    assert_includes ids, workspaces(:two).id.to_s
  end

  # --- MCP 2026-07-28 transport ----------------------------------------------

  test "initialize is not a method on 2026-07-28" do
    result = mcp_post(mcp_rpc("initialize"), token: @read_token.raw_token)

    assert_response :not_found
    assert_equal(-32_601, result["error"]["code"])
    assert_includes result["error"]["message"], "2026-07-28"
  end

  test "a client opening with the old handshake is told which versions to speak" do
    payload = {jsonrpc: "2.0", id: 1, method: "initialize",
               params: {protocolVersion: "2025-06-18", capabilities: {}, clientInfo: {name: "old", version: "1"}}}

    post mcp_endpoint_url, params: payload.to_json,
      headers: auth_headers(@read_token.raw_token).merge("Content-Type" => "application/json")

    assert_response :bad_request
    result = response.parsed_body
    assert_equal(-32_022, result["error"]["code"])
    assert_equal({"supported" => ["2026-07-28"], "requested" => "2025-06-18"}, result["error"]["data"])
  end

  test "ping is not a method on 2026-07-28" do
    result = mcp_post(mcp_rpc("ping"), token: @read_token.raw_token)

    assert_response :not_found
    assert_equal(-32_601, result["error"]["code"])
  end

  test "server/discover describes the server" do
    result = mcp_post(mcp_rpc("server/discover"), token: @read_token.raw_token)["result"]

    assert_response :success
    assert_equal ["2026-07-28"], result["supportedVersions"]
    assert_equal({"tools" => {}}, result["capabilities"])
    assert_equal "complete", result["resultType"]
    assert_equal 3_600_000, result["ttlMs"]
    assert_equal "private", result["cacheScope"]
    assert_equal({"name" => "recuerd0", "version" => "1.0.0"}, result["_meta"]["io.modelcontextprotocol/serverInfo"])
  end

  test "server/discover requires a token" do
    mcp_post(mcp_rpc("server/discover"))

    assert_response :unauthorized
  end

  test "tools/list carries cache hints and the result type" do
    result = mcp_post(mcp_rpc("tools/list"), token: @read_token.raw_token)["result"]

    assert_equal 300_000, result["ttlMs"]
    assert_equal "private", result["cacheScope"]
    assert_equal "complete", result["resultType"]
    assert result["_meta"]["io.modelcontextprotocol/serverInfo"].present?
  end

  test "tool results carry the result type and server info, errors included" do
    result = mcp_post(mcp_rpc("tools/call", name: "read_memory", arguments: {memory_id: "0"}), token: @read_token.raw_token)

    assert result.dig("result", "isError")
    assert_equal "complete", result.dig("result", "resultType")
    assert result.dig("result", "_meta", "io.modelcontextprotocol/serverInfo").present?
  end

  test "the server never issues a session id" do
    mcp_post(mcp_rpc("tools/list"), token: @read_token.raw_token, headers: {"Mcp-Session-Id" => "abc"})

    assert_response :success
    assert_nil response.headers["Mcp-Session-Id"]
  end

  test "a request missing a required _meta key is invalid params" do
    [McpController::PROTOCOL_VERSION_META, McpController::CLIENT_CAPABILITIES_META].each do |key|
      payload = mcp_rpc("tools/list", meta: mcp_meta.except(key))
      result = mcp_post(payload, token: @read_token.raw_token)

      assert_response :bad_request
      assert_equal(-32_602, result["error"]["code"])
      assert_equal "Missing required _meta key: #{key}", result["error"]["message"]
    end
  end

  test "an unsupported protocol version names the supported ones" do
    result = mcp_post(mcp_rpc("tools/list", meta: mcp_meta(version: "2025-06-18")), token: @read_token.raw_token)

    assert_response :bad_request
    assert_equal(-32_022, result["error"]["code"])
    assert_equal({"supported" => ["2026-07-28"], "requested" => "2025-06-18"}, result["error"]["data"])
  end

  test "each transport header must be present and match the body" do
    payload = mcp_rpc("tools/call", name: "list_workspaces", arguments: {})

    %w[MCP-Protocol-Version Mcp-Method Mcp-Name].each do |header|
      [nil, "wrong"].each do |value|
        result = mcp_post(payload, token: @read_token.raw_token, headers: {header => value})

        assert_response :bad_request, "#{header}=#{value.inspect}"
        assert_equal(-32_020, result["error"]["code"])
        assert_includes result["error"]["message"], header
      end
    end
  end

  test "a base64-encoded Mcp-Name header is decoded before comparing" do
    payload = mcp_rpc("tools/call", name: "list_workspaces", arguments: {})
    encoded = "=?base64?#{Base64.strict_encode64("list_workspaces")}?="
    result = mcp_post(payload, token: @read_token.raw_token, headers: {"Mcp-Name" => encoded})

    assert_response :success
    assert_nil result["error"]
  end

  test "an unknown tool is invalid params" do
    result = mcp_post(mcp_rpc("tools/call", name: "nope", arguments: {}), token: @read_token.raw_token)

    assert_response :success
    assert_equal(-32_602, result["error"]["code"])
    assert_equal "Unknown tool: nope", result["error"]["message"]
  end

  test "a null id is an invalid request" do
    result = mcp_post(mcp_rpc("tools/list", id: nil), token: @read_token.raw_token)

    assert_response :bad_request
    assert_equal(-32_600, result["error"]["code"])
    assert_equal "Invalid Request: id must not be null", result["error"]["message"]
  end

  test "a notification without an id is acknowledged with 202 and no body" do
    mcp_post(mcp_rpc("notifications/cancelled").except(:id), token: @read_token.raw_token)

    assert_response :accepted
    assert_empty response.body
  end

  test "GET and DELETE on /mcp answer 405 with or without a token" do
    requests = [
      ->(headers) { get "/mcp", headers: headers.merge("Accept" => "text/event-stream") },
      ->(headers) { get "/mcp", headers: headers.merge("MCP-Protocol-Version" => "2026-07-28") },
      ->(headers) { delete "/mcp", headers: headers }
    ]
    requests.product([{}, auth_headers(@read_token.raw_token)]).each do |request, headers|
      request.call(headers)

      assert_response :method_not_allowed
      assert_equal "POST", response.headers["Allow"]
      assert_empty response.body
    end
  end

  test "a browser still gets the MCP docs page" do
    get "/mcp"

    assert_response :success
    assert_equal "text/html", response.media_type
  end

  test "CORS preflight allows the 2026-07-28 headers and no session header" do
    process :options, "/mcp"

    allowed = response.headers["access-control-allow-headers"]
    assert_includes allowed, "Mcp-Method"
    assert_includes allowed, "Mcp-Name"
    assert_not_includes allowed, "Mcp-Session-Id"
  end

  # --- Audience binding (RFC 8707) --------------------------------------------

  test "an OAuth token issued for another resource is refused" do
    token = oauth_token(permission: "read_only", scope: "memories:read", audience: "https://elsewhere.example/mcp")
    mcp_post(mcp_rpc("tools/list"), token: token.raw_token)

    assert_response :unauthorized
  end

  test "an OAuth token without an audience is refused" do
    token = oauth_token(permission: "read_only", scope: "memories:read", audience: nil)
    mcp_post(mcp_rpc("tools/list"), token: token.raw_token)

    assert_response :unauthorized
  end

  test "an OAuth token for this resource is accepted" do
    mcp_post(mcp_rpc("tools/list"), token: @read_token.raw_token)

    assert_response :success
  end

  test "a manual API token is accepted on /mcp" do
    result = mcp_post(mcp_rpc("tools/list"), token: "test_read_token_123")

    assert_response :success
    assert_equal 13, result["result"]["tools"].size
  end

  # --- Insufficient scope ------------------------------------------------------

  test "unlink_memories is denied for a read_only token" do
    a = Memory.create_with_content(@workspace, title: "A", content: "b")
    b = Memory.create_with_content(@workspace, title: "B", content: "b")
    result = mcp_post(
      mcp_rpc("tools/call", name: "unlink_memories", arguments: {memory_id: a.id.to_s, to_memory_id: b.id.to_s}),
      token: @read_token.raw_token
    )
    assert_insufficient_scope(result)
  end

  test "update_memory is denied for a read_only token" do
    memory = Memory.create_with_content(@workspace, title: "A", content: "b")
    result = mcp_post(
      mcp_rpc("tools/call", name: "update_memory", arguments: {memory_id: memory.id.to_s, title: "Z"}),
      token: @read_token.raw_token
    )
    assert_insufficient_scope(result)
    assert_equal "A", memory.reload.title
  end

  # --- Malformed bodies --------------------------------------------------------

  test "a non-object body is an invalid request" do
    ["[]", "\"text\"", "42"].each do |body|
      post "/mcp", params: body, headers: mcp_headers({method: "tools/list"}).merge(auth_headers(@read_token.raw_token))

      assert_response :bad_request
      assert_equal(-32_600, JSON.parse(response.body)["error"]["code"])
    end
  end

  test "params that are not an object read as missing meta" do
    ["text", []].each do |params|
      result = mcp_post({jsonrpc: "2.0", id: 1, method: "tools/list", params: params}, token: @read_token.raw_token)

      assert_response :bad_request
      assert_equal(-32_602, result["error"]["code"])
    end
  end

  test "string arguments on create_memory never raise" do
    result = mcp_post(mcp_rpc("tools/call", name: "create_memory", arguments: "nope"), token: @full_token.raw_token)

    assert_response :success
    assert(result.dig("result", "isError") || result.dig("error", "code") == -32_602, result.inspect)
  end

  test "string arguments on list_workspaces are ignored" do
    result = mcp_post(mcp_rpc("tools/call", name: "list_workspaces", arguments: "nope"), token: @read_token.raw_token)

    assert_response :success
    assert_nil result["result"]["isError"]
  end

  private

  # An OAuth token for account two, used to prove account one is out of reach.
  def foreign_account_token
    @foreign_account_token ||= users(:two).access_tokens.create!(
      oauth_client: @client,
      permission: "full_access",
      oauth_scope: "memories:read memories:write",
      audience: "http://www.example.com/mcp",
      expires_at: 1.hour.from_now
    ).raw_token
  end

  def assert_insufficient_scope(result)
    assert_response :forbidden
    assert_equal 'Bearer error="insufficient_scope", scope="memories:write", ' \
      'resource_metadata="http://www.example.com/.well-known/oauth-protected-resource/mcp"',
      response.headers["WWW-Authenticate"]
    assert_equal(-32_001, result["error"]["code"])
    assert_equal "Insufficient scope — write access required", result["error"]["message"]
  end

  def assert_tool_error(message, name, arguments, token:)
    result = mcp_post(mcp_rpc("tools/call", name: name, arguments: arguments), token: token)

    assert result.dig("result", "isError"), "#{name} did not report an error: #{result.inspect}"
    assert_equal message, result.dig("result", "content").first["text"], name
  end

  def create_workspace_without_starter_map(name)
    @account.workspaces.create!(name: name).tap do |workspace|
      workspace.memories.find_by!(title: WorkspaceStarter::TITLE).destroy!
    end
  end

  def oauth_token(permission:, scope:, expires_at: 1.hour.from_now, audience: "http://www.example.com/mcp")
    @user.access_tokens.create!(
      oauth_client: @client,
      permission: permission,
      oauth_scope: scope,
      audience: audience,
      expires_at: expires_at
    )
  end

  # Calls a tool and returns its parsed JSON result (the value tools return),
  # not the JSON-RPC envelope. Defaults to the read-only token.
  def call_tool(name, arguments, token: @read_token.raw_token)
    result = mcp_post(mcp_rpc("tools/call", name: name, arguments: arguments), token: token)
    JSON.parse(result["result"]["content"].first["text"])
  end
end
