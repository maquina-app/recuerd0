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

  # Scoping tests
  test "memories scoped to workspace" do
    workspaces(:two)
    other_memory = memories(:two)

    get workspace_memory_url(@workspace, other_memory, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :not_found
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
