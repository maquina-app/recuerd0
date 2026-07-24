require "test_helper"

class ApiMemoriesTest < ActionDispatch::IntegrationTest
  HISTORICAL_VERSION_ERROR =
    "historical versions are immutable — update the current version or create a new version"

  setup do
    @workspace = workspaces(:one)
    @memory = memories(:one)
    @full_access_token = "test_full_token_456"
    @read_only_token = "test_read_token_123"
  end

  # Index tests
  test "index returns memories json" do
    get workspace_memories_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
  end

  test "index includes pagination headers" do
    get workspace_memories_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    assert response.headers["X-Page"].present?
    assert response.headers["X-Total"].present?
  end

  # Show tests
  test "show returns memory with content" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @memory.title, json["title"]
    assert json.key?("content")
    assert json["content"].key?("body")
    assert json.key?("workspace")
    assert json.key?("links_count")
  end

  test "show returns 404 for non-existent memory" do
    get workspace_memory_url(@workspace, id: 999999, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :not_found
  end

  # Create tests
  test "create memory via api" do
    assert_difference "Memory.count", 1 do
      post workspace_memories_url(@workspace, format: :json),
        params: {memory: {title: "API Memory", content: "Created via API", tags: ["api"]}},
        headers: auth_headers(@full_access_token)
    end

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "API Memory", json["title"]
    assert_includes json["tags"], "api"
    assert_equal "Created via API", json["content"]["body"]
  end

  test "create memory requires full_access token" do
    assert_no_difference "Memory.count" do
      post workspace_memories_url(@workspace, format: :json),
        params: {memory: {title: "Should Fail"}},
        headers: auth_headers(@read_only_token)
    end

    assert_response :forbidden
  end

  # Update tests
  test "update memory via api" do
    patch workspace_memory_url(@workspace, @memory, format: :json),
      params: {memory: {title: "Updated Title", content: "Updated content"}},
      headers: auth_headers(@full_access_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Updated Title", json["title"]
    assert_equal "Updated content", json["content"]["body"]
  end

  test "root id update targets the current version and remains visible through reads" do
    workspace = @workspace.account.workspaces.create!(name: "Root Update")
    original_body = "# Version one\n\nKeep these bytes.\n"
    root = Memory.create_with_content(workspace,
      title: "Version one", content: original_body, tags: ["v1"])
    current = root.create_version!(
      title: "Version two", content: "Replace me", tags: ["v2"]
    )

    assert_no_difference -> { root.all_versions.count } do
      patch workspace_memory_url(workspace, root, format: :json),
        params: {
          memory: {
            title: "Updated current",
            content: "# Updated\n\nCurrent body.\n",
            tags: ["current", "edited"]
          }
        },
        headers: auth_headers(@full_access_token)
    end

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal current.id, json["id"]
    assert_equal "Updated current", json["title"]
    assert_equal "# Updated\n\nCurrent body.\n", json["content"]["body"]
    assert_equal ["current", "edited"], json["tags"]

    current.reload
    assert_equal "Updated current", current.title
    assert_equal "# Updated\n\nCurrent body.\n", current.content.body.content
    assert_equal ["current", "edited"], current.tags
    assert_equal "Version one", root.reload.title
    assert_equal ["v1"], root.tags
    assert_equal original_body.bytes, root.content.body.content.bytes

    get workspace_memory_url(workspace, root, format: :json),
      headers: auth_headers(@read_only_token)
    assert_response :success
    shown = JSON.parse(response.body)
    assert_equal "Updated current", shown["title"]
    assert_equal "# Updated\n\nCurrent body.\n", shown["content"]["body"]

    get workspace_memories_url(workspace, format: :json),
      headers: auth_headers(@read_only_token)
    assert_response :success
    listed = JSON.parse(response.body).find { |memory| memory["id"] == current.id }
    assert_equal "Updated current", listed["title"]
    assert_equal ["current", "edited"], listed["tags"]
  end

  test "historical child update is rejected without changing data or touching the root" do
    workspace = @workspace.account.workspaces.create!(name: "Immutable History")
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

    assert_no_difference -> { root.all_versions.count } do
      patch workspace_memory_url(workspace, historical, format: :json),
        params: {
          memory: {
            title: "Corrupted",
            content: "Corrupted body",
            tags: ["corrupted"],
            category: "preference"
          }
        },
        headers: auth_headers(@full_access_token)
    end

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", json.dig("error", "code")
    assert_equal HISTORICAL_VERSION_ERROR, json.dig("error", "message")
    assert_equal [HISTORICAL_VERSION_ERROR], json.dig("error", "details", "base")

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

  test "current child update touches the root and moves it first in updated order" do
    workspace = @workspace.account.workspaces.create!(name: "Current Child Update")
    root = Memory.create_with_content(workspace, title: "Version one", content: "First")
    current = root.create_version!(title: "Version two", content: "Second")
    other = Memory.create_with_content(workspace, title: "Other memory", content: "Other")
    root.update_column(:updated_at, 2.days.ago)
    other.update_column(:updated_at, 1.day.ago)
    root_updated_at = root.reload.updated_at

    travel_to 1.hour.from_now do
      patch workspace_memory_url(workspace, current, format: :json),
        params: {memory: {title: "Direct current update"}},
        headers: auth_headers(@full_access_token)
    end

    assert_response :success
    assert_equal "Direct current update", JSON.parse(response.body)["title"]
    assert_operator root.reload.updated_at, :>, root_updated_at

    get workspace_memories_url(workspace, format: :json),
      params: {sort: "updated_at", direction: "desc"},
      headers: auth_headers(@read_only_token)
    assert_response :success
    assert_equal current.id, JSON.parse(response.body).first["id"]
  end

  test "root id blank overwrite checks the non-empty current body and touches nothing" do
    workspace = @workspace.account.workspaces.create!(name: "Current Blank Guard")
    root = Memory.create_with_content(workspace, title: "Blank v1", content: "")
    current = root.create_version!(title: "Nonblank v2", content: "Existing current body")
    root.update_column(:updated_at, 2.days.ago)
    current.update_column(:updated_at, 1.day.ago)
    root_updated_at = root.reload.updated_at
    current_updated_at = current.reload.updated_at

    assert_no_difference -> { root.all_versions.count } do
      patch workspace_memory_url(workspace, root, format: :json),
        params: {memory: {title: "Must roll back", content: ""}},
        headers: auth_headers(@full_access_token)
    end

    assert_response :unprocessable_entity
    assert_equal "Blank v1", root.reload.title
    assert_equal "", root.content.body.content
    assert_equal root_updated_at, root.updated_at
    assert_equal "Nonblank v2", current.reload.title
    assert_equal "Existing current body", current.content.body.content
    assert_equal current_updated_at, current.updated_at
  end

  test "metadata-only update preserves multiline content" do
    body = "# Exact Markdown\n\n- one\n- two\n\nTrailing line\n"
    memory = Memory.create_with_content(@workspace, title: "Keep body", content: body)

    patch workspace_memory_url(@workspace, memory, format: :json),
      params: {memory: {tags: ["updated"]}},
      headers: auth_headers(@full_access_token)

    assert_response :success
    assert_equal ["updated"], memory.reload.tags
    assert_equal body, memory.content.body.content
  end

  test "blank content update returns 422 and rolls back sibling fields" do
    memory = Memory.create_with_content(@workspace, title: "Before", content: "Existing body")

    patch workspace_memory_url(@workspace, memory, format: :json),
      params: {memory: {title: "After", content: ""}},
      headers: auth_headers(@full_access_token)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal [I18n.t("activerecord.errors.models.memory.attributes.content.blank_overwrite")],
      json.dig("error", "details", "content")
    assert_equal "Before", memory.reload.title
    assert_equal "Existing body", memory.content.body.content
  end

  test "update memory requires full_access token" do
    patch workspace_memory_url(@workspace, @memory, format: :json),
      params: {memory: {title: "Should Not Update"}},
      headers: auth_headers(@read_only_token)

    assert_response :forbidden
  end

  # Destroy tests
  test "destroy memory via api" do
    assert_difference "Memory.count", -1 do
      delete workspace_memory_url(@workspace, @memory, format: :json),
        headers: auth_headers(@full_access_token)
    end

    assert_response :no_content
  end

  test "destroy memory requires full_access token" do
    assert_no_difference "Memory.count" do
      delete workspace_memory_url(@workspace, @memory, format: :json),
        headers: auth_headers(@read_only_token)
    end

    assert_response :forbidden
  end

  # Version resolution tests
  test "show returns current version content for root memory with versions" do
    parent = memories(:versioned_parent)
    parent.create_version!(title: "Latest Title", content: "Latest body")

    get workspace_memory_url(parent.workspace, parent, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "Latest Title", json["title"]
    assert_equal "Latest body", json["content"]["body"]
  end

  test "show returns specific version when requesting child version ID" do
    parent = memories(:versioned_parent)
    v2 = parent.create_version!(title: "V2 Title", content: "V2 body")
    parent.create_version!(title: "V3 Title", content: "V3 body")

    get workspace_memory_url(parent.workspace, v2, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "V2 Title", json["title"]
  end

  test "index returns current version data for versioned memories" do
    parent = memories(:versioned_parent)
    parent.create_version!(title: "Current Title", content: "Current body")

    get workspace_memories_url(parent.workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    versioned = json.find { |m| m["title"] == "Current Title" }
    assert_not_nil versioned, "Expected current version title in index response"
  end

  # Filter tests
  test "index filters by title glob pattern" do
    get workspace_memories_url(@workspace, format: :json),
      params: {title: "Meeting*"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json.all? { |m| m["title"].start_with?("Meeting") }
  end

  test "index filters by tags" do
    get workspace_memories_url(@workspace, format: :json),
      params: {tags: "work,meetings"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    json.each do |m|
      assert_includes m["tags"], "work"
      assert_includes m["tags"], "meetings"
    end
  end

  test "index filters by source" do
    get workspace_memories_url(@workspace, format: :json),
      params: {source: "manual"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json.all? { |m| m["source"] == "manual" }
  end

  test "index supports sorting" do
    get workspace_memories_url(@workspace, format: :json),
      params: {sort: "title", direction: "asc"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    titles = json.map { |m| m["title"] }
    assert_equal titles.sort, titles
  end

  test "index supports per_page" do
    get workspace_memories_url(@workspace, format: :json),
      params: {per_page: 1},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json.length <= 1
    assert_equal "1", response.headers["X-Per-Page"]
  end

  # Line range tests
  test "show includes total_lines in content" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json["content"].key?("total_lines")
    assert json["content"].key?("line_start")
    assert json["content"].key?("line_end")
  end

  test "show returns line range with line_start and line_end" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      params: {line_start: 1, line_end: 1},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json["content"]["line_start"]
    assert_equal 1, json["content"]["line_end"]
    refute_includes json["content"]["body"], "\n"
  end

  test "show returns 422 when line_start > line_end" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      params: {line_start: 5, line_end: 1},
      headers: auth_headers(@read_only_token)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", json["error"]["code"]
  end

  test "show returns full content when no line params" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal @memory.content.body.content, json["content"]["body"]
    assert_equal 1, json["content"]["line_start"]
  end

  # Grep mode tests
  test "show grep mode returns matches instead of body" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      params: {mode: "grep", q: "Meeting"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json["content"].key?("matches")
    assert json["content"].key?("total_lines")
    refute json["content"].key?("body")
  end

  test "show grep mode requires q param" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      params: {mode: "grep"},
      headers: auth_headers(@read_only_token)

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_equal "VALIDATION_ERROR", json["error"]["code"]
  end

  test "show grep mode with context returns surrounding lines" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      params: {mode: "grep", q: "project", context: 1},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json["content"]["matches"].present?
  end

  test "show grep mode with before and after params" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      params: {mode: "grep", q: "Meeting", before: 0, after: 2},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    match = json["content"]["matches"].first
    assert match.key?("line_number")
    assert match.key?("line")
    assert match.key?("context_before")
    assert match.key?("context_after")
  end

  test "show grep mode returns empty matches for no hits" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      params: {mode: "grep", q: "xyznonexistent"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [], json["content"]["matches"]
  end

  test "show without mode=grep returns full body" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json["content"].key?("body")
    refute json["content"].key?("matches")
  end

  # Caching tests
  test "show sets ETag and Cache-Control headers" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    assert response.headers["ETag"].present?
    assert_includes response.headers["Cache-Control"], "private"
  end

  test "show returns 304 when ETag matches" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    etag = response.headers["ETag"]

    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token).merge("If-None-Match" => etag)

    assert_response :not_modified
  end

  test "show returns 200 after memory content changes" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    etag = response.headers["ETag"]

    @memory.touch

    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token).merge("If-None-Match" => etag)

    assert_response :success
  end

  test "show does not return 304 for grep mode even with matching ETag" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    etag = response.headers["ETag"]

    get workspace_memory_url(@workspace, @memory, format: :json),
      params: {mode: "grep", q: "Meeting"},
      headers: auth_headers(@read_only_token).merge("If-None-Match" => etag)

    assert_response :success
  end

  test "show does not return 304 for line range mode even with matching ETag" do
    get workspace_memory_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    etag = response.headers["ETag"]

    get workspace_memory_url(@workspace, @memory, format: :json),
      params: {line_start: 1, line_end: 1},
      headers: auth_headers(@read_only_token).merge("If-None-Match" => etag)

    assert_response :success
  end

  # Scoping tests
  test "memories scoped to workspace" do
    workspaces(:two)
    other_memory = memories(:two)

    get workspace_memory_url(@workspace, other_memory, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :not_found
  end

  # Category tests
  test "create memory with category persists it" do
    post workspace_memories_url(@workspace, format: :json),
      params: {memory: {title: "Cat", content: "b", category: "decision"}},
      headers: auth_headers(@full_access_token)

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "decision", json["category"]
  end

  test "create memory without category defaults to general" do
    post workspace_memories_url(@workspace, format: :json),
      params: {memory: {title: "CatDefault", content: "b"}},
      headers: auth_headers(@full_access_token)

    assert_response :created
    json = JSON.parse(response.body)
    assert_equal "general", json["category"]
  end

  test "create memory with invalid category returns 422" do
    post workspace_memories_url(@workspace, format: :json),
      params: {memory: {title: "CatBad", content: "b", category: "bogus"}},
      headers: auth_headers(@full_access_token)

    assert_response :unprocessable_entity
  end

  test "update memory category via api" do
    patch workspace_memory_url(@workspace, @memory, format: :json),
      params: {memory: {category: "preference"}},
      headers: auth_headers(@full_access_token)

    assert_response :success
    assert_equal "preference", @memory.reload.category
  end

  test "index filters by category" do
    Memory.create_with_content(@workspace, title: "CatFilter1", content: "b", category: "decision")
    Memory.create_with_content(@workspace, title: "CatFilter2", content: "b", category: "discovery")

    get workspace_memories_url(@workspace, format: :json, category: "decision"),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    titles = json.map { |m| m["title"] }
    assert_includes titles, "CatFilter1"
    assert_not_includes titles, "CatFilter2"
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
