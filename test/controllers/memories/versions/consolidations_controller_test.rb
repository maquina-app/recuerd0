require "test_helper"

class Memories::Versions::ConsolidationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @memory = memories(:versioned_parent)
    @memory.create_version!(content: "v2 content")
    sign_in_as(@user)
  end

  test "create consolidates versions" do
    assert @memory.all_versions.count > 1
    post workspace_memory_version_consolidation_url(@workspace, @memory, @memory)
    assert_equal 1, @memory.reload.all_versions.count
  end
end
