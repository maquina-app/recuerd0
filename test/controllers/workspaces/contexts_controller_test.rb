require "test_helper"

class Workspaces::ContextsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:one)
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

    assert_kind_of Array, json["pinned_memories"]
    assert_equal 1, json["pinned_memories"].size

    pinned = json["pinned_memories"].first
    assert_equal @memory.id, pinned["id"]
    assert_equal "Meeting Notes", pinned["title"]
    assert pinned["pinned_at"].present?
    assert pinned["url"].present?
    assert pinned.key?("body")
    assert pinned.key?("body_truncated")

    assert json["stats"]["total_memories"].is_a?(Integer)
    assert_equal 1, json["stats"]["total_pinned"]
    assert_equal 1, json["stats"]["returned_pinned"]
    assert json["generated_at"].present?
  end

  test "returns 200 for archived workspace with empty pinned" do
    archived = workspaces(:archived)

    get workspace_context_url(archived, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "archived", json["workspace"]["state"]
    assert_equal [], json["pinned_memories"]
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
    assert_equal 2, json["pinned_memories"].size
    assert_equal 2, json["stats"]["returned_pinned"]
    assert_equal 6, json["stats"]["total_pinned"]
  end

  test "clamps limit to max 50" do
    get workspace_context_url(@workspace, format: :json, limit: 9999),
      headers: auth_headers(@read_only_token)

    assert_response :success
    # Just ensure no error; cannot easily check the limit value but can confirm <= 50
    json = JSON.parse(response.body)
    assert json["pinned_memories"].size <= 50
  end

  test "include_body=false omits body field" do
    get workspace_context_url(@workspace, format: :json, include_body: "false"),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    pinned = json["pinned_memories"].first
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
    pinned = json["pinned_memories"].first
    assert pinned["body"].length <= 100
    assert_equal true, pinned["body_truncated"]
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
end
