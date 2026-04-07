require "test_helper"

class Memories::LinksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @workspace = workspaces(:one)
    @memory = memories(:one)
    @other_workspace = Workspace.create!(name: "Linkable", account: @account)
    @other_memory = @other_workspace.memories.create!(title: "Linkable mem")
    @other_memory.create_content!(body: "x")
    @read_only_token = "test_read_token_123"
    @full_token = "test_full_token_456"
  end

  test "index returns linked memories with workspace embedded" do
    MemoryLink.create!(from_memory: @memory, to_memory: @other_memory)

    get workspace_memory_links_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 1, json.size
    assert_equal @other_memory.id, json.first["id"]
    assert_equal @other_workspace.id, json.first["workspace"]["id"]
    assert_equal @other_workspace.name, json.first["workspace"]["name"]
  end

  test "index returns 304 on matching etag" do
    MemoryLink.create!(from_memory: @memory, to_memory: @other_memory)

    get workspace_memory_links_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token)
    assert_response :success
    etag = response.headers["ETag"]
    assert etag.present?

    get workspace_memory_links_url(@workspace, @memory, format: :json),
      headers: auth_headers(@read_only_token).merge("If-None-Match" => etag)
    assert_response :not_modified
  end

  test "index returns 401 without auth" do
    get workspace_memory_links_url(@workspace, @memory, format: :json)
    assert_response :unauthorized
  end

  test "index returns 404 for memory in another account" do
    other = workspaces(:two)
    get workspace_memory_links_url(other, memories(:two), format: :json),
      headers: auth_headers(@read_only_token)
    assert_response :not_found
  end

  test "create with valid to_memory_id returns 201 and persists link" do
    assert_difference("MemoryLink.count", 1) do
      post workspace_memory_links_url(@workspace, @memory, format: :json),
        params: {to_memory_id: @other_memory.id},
        headers: auth_headers(@full_token)
    end
    assert_response :created
    json = JSON.parse(response.body)
    assert_equal @other_memory.id, json["id"]
  end

  test "create with self id returns 422" do
    post workspace_memory_links_url(@workspace, @memory, format: :json),
      params: {to_memory_id: @memory.id},
      headers: auth_headers(@full_token)
    assert_response :unprocessable_entity
  end

  test "create with cross-account id returns 422" do
    cross = memories(:two)
    post workspace_memory_links_url(@workspace, @memory, format: :json),
      params: {to_memory_id: cross.id},
      headers: auth_headers(@full_token)
    assert_response :unprocessable_entity
  end

  test "create with already linked id returns 422" do
    MemoryLink.create!(from_memory: @memory, to_memory: @other_memory)
    post workspace_memory_links_url(@workspace, @memory, format: :json),
      params: {to_memory_id: @other_memory.id},
      headers: auth_headers(@full_token)
    assert_response :unprocessable_entity
  end

  test "create requires full access" do
    post workspace_memory_links_url(@workspace, @memory, format: :json),
      params: {to_memory_id: @other_memory.id},
      headers: auth_headers(@read_only_token)
    assert_response :forbidden
  end

  test "destroy removes link by other-memory id" do
    MemoryLink.create!(from_memory: @memory, to_memory: @other_memory)
    assert_difference("MemoryLink.count", -1) do
      delete workspace_memory_link_url(@workspace, @memory, @other_memory.id, format: :json),
        headers: auth_headers(@full_token)
    end
    assert_response :no_content
  end

  test "destroy returns 404 if link does not exist" do
    delete workspace_memory_link_url(@workspace, @memory, @other_memory.id, format: :json),
      headers: auth_headers(@full_token)
    assert_response :not_found
  end

  test "destroy returns 404 for cross-account memory" do
    cross = memories(:two)
    delete workspace_memory_link_url(@workspace, @memory, cross.id, format: :json),
      headers: auth_headers(@full_token)
    assert_response :not_found
  end

  test "destroy requires full access" do
    MemoryLink.create!(from_memory: @memory, to_memory: @other_memory)
    delete workspace_memory_link_url(@workspace, @memory, @other_memory.id, format: :json),
      headers: auth_headers(@read_only_token)
    assert_response :forbidden
  end
end
