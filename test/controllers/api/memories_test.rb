require "test_helper"

class ApiMemoriesTest < ActionDispatch::IntegrationTest
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
    assert_equal @memory.content.body, json["content"]["body"]
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
