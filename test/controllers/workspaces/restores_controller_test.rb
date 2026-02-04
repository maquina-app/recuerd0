require "test_helper"

class Workspaces::RestoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create restores deleted workspace" do
    workspace = workspaces(:deleted)
    post restore_deleted_workspace_url(workspace)
    assert_not workspace.reload.deleted?
  end
end
