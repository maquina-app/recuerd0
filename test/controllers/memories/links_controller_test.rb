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

  # -- browser (HTML) link management --
  #
  # The JSON resource keeps defaults: {format: :json}; these routes are a
  # separate HTML surface so API clients that omit the extension are unaffected.

  test "browser can create a link and is redirected back to the memory" do
    sign_in_as(@user)

    assert_difference -> { MemoryLink.count }, 1 do
      post workspace_memory_memory_linking_url(@workspace, @memory),
        params: {to_memory_id: @other_memory.id}
    end

    assert_redirected_to workspace_memory_path(@workspace, @memory)
    assert_equal 303, response.status, "a redirect Turbo may follow must be See Other"
  end

  test "browser can remove a link by the other memory's id" do
    sign_in_as(@user)
    MemoryLink.create!(from_memory: @memory, to_memory: @other_memory)

    assert_difference -> { MemoryLink.count }, -1 do
      delete workspace_memory_memory_linking_remove_url(@workspace, @memory, other_id: @other_memory.id)
    end

    assert_redirected_to workspace_memory_path(@workspace, @memory)
    assert_equal 303, response.status
  end

  test "memory show always renders the related section, even with no links" do
    sign_in_as(@user)

    get workspace_memory_url(@workspace, @memory)
    assert_response :success

    # Gating this on links_count > 0 made the feature undiscoverable to anyone
    # who had not already used it.
    assert_select "section#related-memories"
    assert_select "h2#related-memories-heading"
    assert_select "#related-memories [data-component=empty]"
  end

  test "memory show names the workspace only for cross-workspace links" do
    sign_in_as(@user)
    same_ws = @workspace.memories.create!(title: "Neighbour")
    same_ws.create_content!(body: "x")
    MemoryLink.create!(from_memory: @memory, to_memory: same_ws)
    MemoryLink.create!(from_memory: @memory, to_memory: @other_memory)

    get workspace_memory_url(@workspace, @memory)
    assert_response :success

    # One marker for the one link that leaves this workspace; printing it on
    # every row made the only fact that matters read as decoration.
    assert_select ".mr-elsewhere", count: 1
    assert_select ".mr-elsewhere", text: /#{@other_workspace.name}/
  end

  test "link picker excludes the memory itself and anything already linked" do
    sign_in_as(@user)
    MemoryLink.create!(from_memory: @memory, to_memory: @other_memory)

    get workspace_memory_url(@workspace, @memory), params: {link_q: "Linkable"}
    assert_response :success

    candidates = @controller.view_assigns["link_candidates"].to_a
    assert_not_includes candidates.map(&:id), @other_memory.id, "already linked"
    assert_not_includes candidates.map(&:id), @memory.id, "itself"
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
