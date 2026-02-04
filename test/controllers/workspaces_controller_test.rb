require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @archived_workspace = workspaces(:archived)
    @deleted_workspace = workspaces(:deleted)

    sign_in_as(@user)
  end

  # -- new --

  test "should get new" do
    get new_workspace_url
    assert_response :success
  end

  # -- create --

  test "should create workspace with valid params" do
    assert_difference("Workspace.count") do
      post workspaces_url, params: {workspace: {name: "New Workspace", description: "A description"}}
    end

    assert_redirected_to workspace_url(Workspace.last)
    assert_equal I18n.t("workspaces.create.created"), flash[:notice]
  end

  test "should not create workspace without name" do
    assert_no_difference("Workspace.count") do
      post workspaces_url, params: {workspace: {name: "", description: "A description"}}
    end

    assert_response :unprocessable_entity
    assert_equal I18n.t("workspaces.create.errors"), flash[:alert]
  end

  test "should not create workspace with name exceeding max length" do
    assert_no_difference("Workspace.count") do
      post workspaces_url, params: {workspace: {name: "a" * 101}}
    end

    assert_response :unprocessable_entity
  end

  # -- edit --

  test "should get edit" do
    get edit_workspace_url(@workspace)
    assert_response :success
  end

  test "should redirect edit for archived workspace" do
    get edit_workspace_url(@archived_workspace)

    assert_redirected_to workspaces_path
    assert_equal I18n.t("workspaces.inactive_workspace"), flash[:alert]
  end

  test "should redirect edit for deleted workspace" do
    get edit_workspace_url(@deleted_workspace)

    assert_redirected_to workspaces_path
    assert_equal I18n.t("workspaces.inactive_workspace"), flash[:alert]
  end

  # -- update --

  test "should update workspace with valid params" do
    patch workspace_url(@workspace), params: {workspace: {name: "Updated Name"}}

    assert_redirected_to workspace_url(@workspace)
    assert_equal I18n.t("workspaces.update.updated"), flash[:notice]
    assert_equal "Updated Name", @workspace.reload.name
  end

  test "should not update workspace with blank name" do
    patch workspace_url(@workspace), params: {workspace: {name: ""}}

    assert_response :unprocessable_entity
    assert_equal I18n.t("workspaces.update.errors"), flash[:alert]
  end

  test "should redirect update for archived workspace" do
    patch workspace_url(@archived_workspace), params: {workspace: {name: "New Name"}}

    assert_redirected_to workspaces_path
    assert_equal I18n.t("workspaces.inactive_workspace"), flash[:alert]
    assert_equal "Old Project", @archived_workspace.reload.name
  end

  test "should redirect update for deleted workspace" do
    patch workspace_url(@deleted_workspace), params: {workspace: {name: "New Name"}}

    assert_redirected_to workspaces_path
    assert_equal I18n.t("workspaces.inactive_workspace"), flash[:alert]
    assert_equal "Deleted Project", @deleted_workspace.reload.name
  end
end
