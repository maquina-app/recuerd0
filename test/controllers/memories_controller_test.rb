require "test_helper"

class MemoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:one)
    sign_in_as(@user)
  end

  test "show renders memory" do
    get workspace_memory_url(@workspace, @memory)
    assert_response :success
  end

  test "new renders form" do
    get new_workspace_memory_url(@workspace)
    assert_response :success
  end

  test "create saves memory with content" do
    assert_difference("Memory.count") do
      post workspace_memories_url(@workspace), params: {
        memory: {title: "New Memory", content: "Some content", tags: ["test"]}
      }
    end
  end

  test "edit renders form" do
    get edit_workspace_memory_url(@workspace, @memory)
    assert_response :success
  end

  test "update changes memory" do
    patch workspace_memory_url(@workspace, @memory), params: {
      memory: {title: "Updated Title", content: "Updated body"}
    }
    assert_redirected_to workspace_memory_url(@workspace, @memory)
    assert_equal "Updated Title", @memory.reload.title
  end

  test "show resolves to current version for root memory with versions" do
    parent = memories(:versioned_parent)
    parent.create_version!(title: "Latest Version", content: "Latest content")

    get workspace_memory_url(parent.workspace, parent)
    assert_response :success
    assert_match "Latest Version", response.body
  end

  test "show renders specific version when navigating to child version" do
    parent = memories(:versioned_parent)
    v2 = parent.create_version!(title: "V2 Specific", content: "V2 content")
    parent.create_version!(title: "V3 Latest", content: "V3 content")

    get workspace_memory_url(parent.workspace, v2)
    assert_response :success
    assert_match "V2 Specific", response.body
  end

  test "destroy removes memory" do
    assert_difference("Memory.count", -1) do
      delete workspace_memory_url(@workspace, @memory)
    end
  end
end
