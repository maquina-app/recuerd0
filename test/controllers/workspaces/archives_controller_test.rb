require "test_helper"

class Workspaces::ArchivesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "index lists archived workspaces" do
    get archived_workspaces_url
    assert_response :success
  end

  test "create archives a workspace" do
    workspace = workspaces(:one)
    post archive_workspace_url(workspace)
    assert workspace.reload.archived?
  end

  test "destroy unarchives a workspace" do
    workspace = workspaces(:archived)
    delete archive_workspace_url(workspace)
    assert_not workspace.reload.archived?
  end
end
