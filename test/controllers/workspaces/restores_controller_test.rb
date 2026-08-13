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
    assert_equal I18n.t("workspaces/restores.create.created", raise: true), flash[:notice]
  end
end
