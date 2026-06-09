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

  test "destroy permanently deletes" do
    workspace = workspaces(:deleted)
    assert_difference("Workspace.count", -1) do
      delete destroy_deleted_workspace_url(workspace)
    end
  end
end
