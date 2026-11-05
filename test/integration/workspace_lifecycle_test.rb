require "test_helper"

class WorkspaceLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
    @workspace = workspaces(:one)
  end

  test "a workspace archived then deleted reads as deleted everywhere, with Restore" do
    @workspace.archive
    @workspace.soft_delete

    get deleted_workspaces_url
    assert_select "##{dom_id_for(@workspace)}" do
      assert_select "[data-component='badge']", text: "Deleted"
      assert_select "[data-component='badge']", text: "Archived", count: 0
    end
    assert_select "a[href=?]", restore_deleted_workspace_path(@workspace), text: /Restore/
    assert_select "a[href=?]", destroy_deleted_workspace_path(@workspace), text: /Delete permanently/
    assert_select "a[data-turbo-method='delete'][href=?]", archive_workspace_path(@workspace), count: 0

    get workspace_url(@workspace)
    assert_redirected_to deleted_workspace_path(@workspace)
    follow_redirect!
    assert_match I18n.t("workspaces.show.deleted_title"), response.body
    assert_no_match I18n.t("workspaces.show.archived_title"), response.body

    get archived_workspace_url(@workspace)
    assert_redirected_to deleted_workspace_path(@workspace)
  end

  test "restore brings it back in one step and says where" do
    @workspace.archive
    @workspace.soft_delete

    post restore_deleted_workspace_url(@workspace)

    assert_redirected_to workspace_path(@workspace)
    assert_equal I18n.t("workspaces/restores.create.created", name: @workspace.name), flash[:notice]
    assert @workspace.reload.active?
  end

  test "unarchiving a deleted workspace no longer reports a false success" do
    @workspace.archive
    @workspace.soft_delete

    delete archive_workspace_url(@workspace)

    assert_redirected_to deleted_workspaces_path
    assert_equal I18n.t("workspaces/archives.deleted", name: @workspace.name), flash[:alert]
    assert @workspace.reload.deleted?
  end

  test "archive and unarchive answer 404 over REST on a deleted workspace" do
    @workspace.soft_delete

    delete archive_workspace_url(@workspace, format: :json), headers: auth_headers("test_full_token_456")
    assert_response :not_found
  end

  test "the header and the filter agree once a memory has versions" do
    workspace = accounts(:one).workspaces.create!(name: "Counts", start_with_map: "0", created_by: users(:one))
    memory = Memory.create_with_content(workspace, title: "A", content: "x")
    2.times { memory.create_version!(content: it.to_s) }
    Memory.create_with_content(workspace, title: "B", content: "x")

    get workspace_url(workspace)

    assert_select ".stat-chip strong", text: "2"
    assert_select ".category-chip .cat-count", text: "2"
  end

  test "the new workspace form offers the map, on by default" do
    get new_workspace_url
    assert_select "input[type=checkbox][name='workspace[start_with_map]'][checked]"

    assert_no_difference("Memory.count") do
      post workspaces_url, params: {workspace: {name: "Blank", start_with_map: "0"}}
    end
  end

  test "a whitespace-only name comes back empty with its error" do
    post workspaces_url, params: {workspace: {name: "   "}}

    assert_response :unprocessable_entity
    assert_equal "", css_select("input[name='workspace[name]']").first["value"].to_s
  end

  test "a system source reads as recuerd0, not as a storage value" do
    workspace = accounts(:one).workspaces.create!(name: "Mapped", created_by: users(:one))

    get workspace_memory_url(workspace, workspace.starter_map)

    assert_select ".src-val", text: I18n.t("memories.memory.source_system")
  end

  test "empty states don't claim you never did it" do
    Workspace.where(account: accounts(:one)).update_all(archived_at: nil, deleted_at: nil)

    get archived_workspaces_url
    assert_match I18n.t("workspaces.archives.index.empty_description"), response.body
    assert_no_match(/haven&#39;t archived/, response.body)
  end

  test "the workspace ID has a visible label" do
    get workspace_url(@workspace)

    assert_select "p:has(code.ws-id) span:not(.sr-only)", text: I18n.t("workspaces.show.workspace_id_label")
  end

  test "pinned page says workspaces" do
    pinned = Memory.create_with_content(workspaces(:one), title: "Pinned one", content: "x")
    pinned.pin!(users(:one))

    get pinned_memories_url

    assert_match(/across \d+ workspaces?/, css_select("main, body").text)
    assert_no_match(/\bprojects?\b/i, css_select("[data-controller='pin-focus'] > div:first-child").text)
  end

  private

  def dom_id_for(record)
    ActionView::RecordIdentifier.dom_id(record)
  end
end
