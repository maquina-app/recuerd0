require "test_helper"

class WorkspacesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @workspace = workspaces(:one)
    @archived_workspace = workspaces(:archived)
    @deleted_workspace = workspaces(:deleted)

    sign_in_as(@user)
  end

  # -- index --

  test "index defaults view mode to list" do
    get workspaces_url
    assert_response :success
    assert_equal "list", @controller.view_assigns["view_mode"]
  end

  test "index with view=grid sets cookie and resolves grid" do
    get workspaces_url(view: "grid")
    assert_response :success
    assert_equal "grid", @controller.view_assigns["view_mode"]
    assert_equal "grid", cookies[:recuerd0_workspace_view]
  end

  test "index resolves view from cookie when no param given" do
    # First request sets the cookie to grid.
    get workspaces_url(view: "grid")
    assert_equal "grid", cookies[:recuerd0_workspace_view]

    # Subsequent request with no view param resolves grid from cookie.
    get workspaces_url
    assert_response :success
    assert_equal "grid", @controller.view_assigns["view_mode"]
  end

  test "index ignores invalid view param" do
    get workspaces_url(view: "bogus")
    assert_response :success
    assert_equal "list", @controller.view_assigns["view_mode"]
  end

  test "index with sort=name orders unpinned workspaces alphabetically" do
    account = accounts(:one)
    account.workspaces.create!(name: "Zebra Workspace")
    account.workspaces.create!(name: "Apple Workspace")

    get workspaces_url(sort: "name")
    assert_response :success
    assert_equal "name", @controller.view_assigns["sort"]

    workspaces = @controller.view_assigns["workspaces"].to_a
    # Pinned workspace(s) first; unpinned tail must be alphabetical.
    pinned = workspaces(:one)
    unpinned_names = workspaces.reject { |w| w == pinned }.map(&:name)
    assert_equal unpinned_names.sort_by(&:downcase), unpinned_names
  end

  test "index sort param defaults to nil for invalid value" do
    get workspaces_url(sort: "bogus")
    assert_response :success
    assert_nil @controller.view_assigns["sort"]
  end

  test "index json returns all active workspaces with pagination headers" do
    account = accounts(:one)
    created = account.workspaces.create!(name: "Extra JSON Workspace")

    get workspaces_url(format: :json)
    assert_response :success

    body = JSON.parse(response.body)
    returned_ids = body.map { |w| w["id"] }

    active_ids = account.workspaces.active.pluck(:id)
    assert_equal active_ids.sort, returned_ids.sort
    assert_includes returned_ids, created.id
    assert response.headers["X-Page"].present?
    assert response.headers["X-Total"].present?
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
