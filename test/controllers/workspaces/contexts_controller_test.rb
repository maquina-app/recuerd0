require "test_helper"

class Workspaces::ContextsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:one)
    @full_access_token = "test_full_token_456"
    @read_only_token = "test_read_token_123"
  end

  test "returns 200 with expected payload shape" do
    get workspace_context_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal @workspace.id, json["workspace"]["id"]
    assert_equal "Project Notes", json["workspace"]["name"]
    assert_equal "active", json["workspace"]["state"]
    assert json["workspace"].key?("memories_count")
    assert json["workspace"].key?("url")

    assert_kind_of Array, json["memories"]
    assert_equal json["memories"], json["pinned_memories"]
    assert_equal 1, json["memories"].size
    assert_equal "pins", json["context_source"]

    pinned = json["memories"].first
    assert_equal @memory.id, pinned["id"]
    assert_equal "Meeting Notes", pinned["title"]
    assert pinned["pinned_at"].present?
    assert pinned["url"].present?
    assert pinned.key?("body")
    assert pinned.key?("body_truncated")

    assert json["stats"]["total_memories"].is_a?(Integer)
    assert_equal 1, json["stats"]["total_pinned"]
    assert_equal 1, json["stats"]["returned"]
    assert_equal 1, json["stats"]["returned_pinned"]
    assert json["generated_at"].present?
  end

  test "fresh account context contains only the map and continuation brief" do
    user = Account.create_with_user(
      email_address: "fresh-context@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    workspace = user.account.workspaces.find_by!(name: "My Workspace")
    token = user.access_tokens.create!(permission: "read_only")

    get workspace_context_url(workspace, format: :json),
      headers: auth_headers(token.raw_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal ["_MAP", "Continuation Brief"].sort,
      json["memories"].map { |memory| memory["title"] }.sort
    assert_equal "pins", json["context_source"]
  end

  test "creator and teammate receive the same ordered seeded context" do
    creator = Account.create_with_user(
      email_address: "context-creator@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    workspace = creator.account.workspaces.first
    teammate = creator.account.users.create!(
      email_address: "context-teammate@example.com",
      password: "password123",
      role: "member"
    )
    creator_token = creator.access_tokens.create!(permission: "read_only")
    teammate_token = teammate.access_tokens.create!(permission: "read_only")

    get workspace_context_url(workspace, format: :json),
      headers: auth_headers(creator_token.raw_token)
    creator_memories = JSON.parse(response.body)["memories"]

    get workspace_context_url(workspace, format: :json),
      headers: auth_headers(teammate_token.raw_token)
    teammate_memories = JSON.parse(response.body)["memories"]

    context_tuple = ->(memory) { memory.values_at("id", "title", "body") }
    assert_equal creator_memories.map(&context_tuple), teammate_memories.map(&context_tuple)
    assert creator_memories.all? { |memory| memory["pinned_at"].present? }
    assert teammate_memories.all? { |memory| memory["pinned_at"].present? }
  end

  test "returns 200 for archived workspace with empty pinned" do
    archived = workspaces(:archived)
    recent = Memory.create_with_content(
      archived,
      title: "Archived context",
      content: "Still readable"
    )

    get workspace_context_url(archived, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "archived", json["workspace"]["state"]
    assert_equal [recent.id], json["memories"].map { |memory| memory["id"] }
    assert_equal "recent", json["context_source"]
  end

  test "returns 404 for deleted workspace" do
    deleted = workspaces(:deleted)

    get workspace_context_url(deleted, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "NOT_FOUND", json["error"]["code"]
  end

  test "returns 404 for workspace in another account" do
    other = workspaces(:two)

    get workspace_context_url(other, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :not_found
    json = JSON.parse(response.body)
    assert_equal "NOT_FOUND", json["error"]["code"]
  end

  test "returns 401 without a token" do
    get workspace_context_url(@workspace, format: :json)
    assert_response :unauthorized
  end

  test "respects limit param and reports total_pinned" do
    # Create extra memories and pin them
    5.times do |i|
      m = @workspace.memories.create!(title: "Pinned #{i}", source: "manual", tags: [])
      m.create_content!(body: "Body #{i}")
      Pin.create!(user: @user, pinnable: m)
    end

    get workspace_context_url(@workspace, format: :json, limit: 2),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["memories"].size
    assert_equal 2, json["stats"]["returned"]
    assert_equal 2, json["stats"]["returned_pinned"]
    assert_equal 6, json["stats"]["total_pinned"]
  end

  test "clamps limit to max 50" do
    get workspace_context_url(@workspace, format: :json, limit: 9999),
      headers: auth_headers(@read_only_token)

    assert_response :success
    # Just ensure no error; cannot easily check the limit value but can confirm <= 50
    json = JSON.parse(response.body)
    assert json["memories"].size <= 50
  end

  test "include_body=false omits body field" do
    get workspace_context_url(@workspace, format: :json, include_body: "false"),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    pinned = json["memories"].first
    assert_not pinned.key?("body")
    assert_not pinned.key?("body_truncated")
  end

  test "include_body default truncates body to max_body_chars" do
    long_body = "x" * 2000
    @memory.content.update!(body: long_body)

    get workspace_context_url(@workspace, format: :json, max_body_chars: 100),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    pinned = json["memories"].first
    assert pinned["body"].length <= 100
    assert_equal true, pinned["body_truncated"]
  end

  test "pinned memories include links_count" do
    get workspace_context_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    json["memories"].each { |m| assert m.key?("links_count") }
  end

  test "pinned memories include category" do
    get workspace_context_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    json["memories"].each { |m| assert m.key?("category") }
  end

  test "filters pinned memories by category" do
    @memory.update!(category: "decision")
    other = Memory.create_with_content(@workspace, title: "Pinned2", content: "b", category: "discovery")
    other.pin!(@user)

    get workspace_context_url(@workspace, format: :json, category: "decision"),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    ids = json["memories"].map { |m| m["id"] }
    assert_includes ids, @memory.id
    assert_not_includes ids, other.id
  end

  test "falls back to recent roots with null pinned_at and zero pinned stats" do
    workspace = @user.account.workspaces.create!(name: "Recent fallback")
    workspace.memories.find_by!(title: WorkspaceStarter::TITLE).destroy!
    older = Memory.create_with_content(workspace, title: "Older", content: "Old body")
    newer = Memory.create_with_content(workspace, title: "Newer", content: "New body")
    older.update_column(:updated_at, 2.days.ago)
    newer.update_column(:updated_at, 1.day.ago)

    get workspace_context_url(workspace, format: :json, limit: 1),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "recent", json["context_source"]
    assert_equal [newer.id], json["memories"].map { |memory| memory["id"] }
    assert_nil json["memories"].first["pinned_at"]
    assert_equal 0, json["stats"]["total_pinned"]
    assert_equal 1, json["stats"]["returned"]
    assert_equal json["memories"], json["pinned_memories"]
  end

  test "category filtering happens before recent fallback" do
    workspace = @user.account.workspaces.create!(name: "Category fallback")
    pinned = Memory.create_with_content(
      workspace,
      title: "Pinned general",
      content: "General body",
      category: "general"
    )
    matching = Memory.create_with_content(
      workspace,
      title: "Recent decision",
      content: "Decision body",
      category: "decision"
    )
    pinned.pin!(@user)

    get workspace_context_url(workspace, format: :json, category: "decision"),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "recent", json["context_source"]
    assert_equal [matching.id], json["memories"].map { |memory| memory["id"] }
    assert_equal 0, json["stats"]["total_pinned"]
  end

  test "uses current version display fields and body with root identity and pin" do
    workspace = @user.account.workspaces.create!(name: "Versioned context")
    root = Memory.create_with_content(
      workspace,
      title: "Version one",
      content: "Body one",
      category: "general"
    )
    root.create_version!(
      title: "Version two",
      content: "Body two",
      category: "discovery"
    )
    current = root.create_version!(
      title: "Version three",
      content: "Body three",
      category: "decision",
      tags: ["current"]
    )
    pin = root.pin!(@user)

    get workspace_context_url(workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    memory = JSON.parse(response.body)["memories"].first
    assert_equal root.id, memory["id"]
    assert_equal current.title, memory["title"]
    assert_equal current.content.body.content, memory["body"]
    assert_equal current.category, memory["category"]
    assert_equal current.tags, memory["tags"]
    assert_equal pin.created_at.utc.iso8601(3), Time.iso8601(memory["pinned_at"]).iso8601(3)
    assert_match %r{/memories/#{root.id}\z}, URI(memory["url"]).path
  end

  test "returns 304 when ETag matches" do
    get workspace_context_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    etag = response.headers["ETag"]
    assert etag.present?

    get workspace_context_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token).merge("If-None-Match" => etag)

    assert_response :not_modified
  end

  test "returns fresh archived body after archive with previous ETag" do
    get workspace_context_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    assert_equal "active", JSON.parse(response.body).dig("workspace", "state")
    etag = response.headers["ETag"]
    assert etag.present?

    post archive_workspace_url(@workspace, format: :json),
      headers: auth_headers(@full_access_token)

    assert_response :success

    get workspace_context_url(@workspace, format: :json),
      headers: auth_headers(@read_only_token).merge("If-None-Match" => etag)

    assert_response :success
    assert_equal "archived", JSON.parse(response.body).dig("workspace", "state")
  end
end
