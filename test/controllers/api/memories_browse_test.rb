require "test_helper"

class ApiBrowseMemoriesTest < ActionDispatch::IntegrationTest
  setup do
    @workspace = workspaces(:one)
    @memory = memories(:one)
    @read_only_token = "test_read_token_123"
    @full_access_token = "test_full_token_456"
  end

  test "returns memories json array with auth" do
    get browse_memories_url(format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_kind_of Array, json
    assert json.any? { |m| m["title"] == "Meeting Notes" }
  end

  test "requires authentication" do
    get browse_memories_url(format: :json)

    assert_response :unauthorized
  end

  test "includes pagination headers" do
    get browse_memories_url(format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    assert response.headers["X-Page"].present?
    assert response.headers["X-Total"].present?
  end

  test "filters by title glob pattern" do
    get browse_memories_url(format: :json),
      params: {title: "Meeting*"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json.all? { |m| m["title"].start_with?("Meeting") }
    assert json.any?, "Expected at least one result matching title glob"
  end

  test "filters by tags" do
    get browse_memories_url(format: :json),
      params: {tags: "work,meetings"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json.any?, "Expected at least one result matching tags"
    json.each do |m|
      assert_includes m["tags"], "work"
      assert_includes m["tags"], "meetings"
    end
  end

  test "filters by source" do
    get browse_memories_url(format: :json),
      params: {source: "manual"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json.any?, "Expected at least one result matching source"
    assert json.all? { |m| m["source"] == "manual" }
  end

  test "filters by workspace_id" do
    get browse_memories_url(format: :json),
      params: {workspace_id: @workspace.id},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json.any?, "Expected at least one result for workspace"
    json.each do |m|
      assert_equal @workspace.id, m["workspace"]["id"]
    end
  end

  test "does not return memories from other accounts" do
    get browse_memories_url(format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    other_memory = memories(:two)
    assert json.none? { |m| m["title"] == other_memory.title },
      "Should not include memories from other accounts"
  end

  test "does not return memories from archived workspaces" do
    get browse_memories_url(format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    archived_workspace = workspaces(:archived)
    assert json.none? { |m| m.dig("workspace", "id") == archived_workspace.id },
      "Should not include memories from archived workspaces"
  end

  test "does not return memories from deleted workspaces" do
    get browse_memories_url(format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    deleted_workspace = workspaces(:deleted)
    assert json.none? { |m| m.dig("workspace", "id") == deleted_workspace.id },
      "Should not include memories from deleted workspaces"
  end

  test "supports sorting" do
    get browse_memories_url(format: :json),
      params: {sort: "title", direction: "asc"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    titles = json.map { |m| m["title"] }
    assert_equal titles.sort_by(&:downcase), titles,
      "Expected memories sorted by title ascending"
  end

  test "supports per_page param" do
    get browse_memories_url(format: :json),
      params: {per_page: 1},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.size
  end

  test "combines multiple filters" do
    get browse_memories_url(format: :json),
      params: {title: "Meeting*", tags: "work"},
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert json.any?, "Expected at least one result with combined filters"
    json.each do |m|
      assert m["title"].start_with?("Meeting"), "Title should match glob"
      assert_includes m["tags"], "work", "Tags should include 'work'"
    end
  end

  private

  def auth_headers(token)
    {"Authorization" => "Bearer #{token}"}
  end
end
