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

  test "index renders grid view when view=grid and persists the shared cookie" do
    get archived_workspaces_url(view: "grid")
    assert_response :success
    assert_equal "grid", cookies[:recuerd0_workspace_view]
  end

  test "index honors the shared workspace view cookie" do
    get workspaces_url(view: "grid") # set preference on the main index
    get archived_workspaces_url # no param -> resolves from shared cookie
    assert_response :success
    assert_select "[data-component=card]"
  end

  test "show renders memories for an archived workspace" do
    workspace = workspaces(:archived)
    Memory.create_with_content(workspace, title: "Archived note", content: "body")

    get archived_workspace_url(workspace)
    assert_response :success
    assert_equal "cards", @controller.view_assigns["memory_view"]
    assert_not_nil @controller.view_assigns["category_counts"]
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
