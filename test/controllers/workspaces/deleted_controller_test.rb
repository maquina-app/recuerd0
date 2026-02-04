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

  test "destroy permanently deletes" do
    workspace = workspaces(:deleted)
    assert_difference("Workspace.count", -1) do
      delete destroy_deleted_workspace_url(workspace)
    end
  end
end
