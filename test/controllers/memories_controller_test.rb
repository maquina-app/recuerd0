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

  test "destroy removes memory" do
    assert_difference("Memory.count", -1) do
      delete workspace_memory_url(@workspace, @memory)
    end
  end
end
