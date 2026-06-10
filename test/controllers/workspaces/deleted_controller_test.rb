require "test_helper"

class Workspaces::DeletedControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index lists deleted workspaces" do
    get deleted_workspaces_url
    assert_response :success
  end

  test "index renders grid view when view=grid and persists the shared cookie" do
    get deleted_workspaces_url(view: "grid")
    assert_response :success
    assert_equal "grid", cookies[:recuerd0_workspace_view]
    assert_select "[data-component=card]"
  end

  test "show renders memories for a deleted workspace" do
    workspace = workspaces(:deleted)
    Memory.create_with_content(workspace, title: "Deleted note", content: "body")

    get deleted_workspace_url(workspace)
    assert_response :success
    assert_equal "cards", @controller.view_assigns["memory_view"]
    assert_not_nil @controller.view_assigns["category_counts"]
  end

  test "destroy permanently deletes" do
    workspace = workspaces(:deleted)
    assert_difference("Workspace.count", -1) do
      delete destroy_deleted_workspace_url(workspace)
    end
  end
end
