require "test_helper"

class Memories::VersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:versioned_parent)
    sign_in_as(@user)
  end

  test "index lists versions" do
    get workspace_memory_versions_url(@workspace, @memory)
    assert_response :success
  end

  test "create makes new version" do
    assert_difference("Memory.count") do
      post workspace_memory_versions_url(@workspace, @memory)
    end
  end
end
