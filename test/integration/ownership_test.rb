require "test_helper"

# Members delete only what they own; admins delete anything; a record with no
# recorded creator belongs to the admin. Two-version memories throughout, since
# the rule reads the root's owner.
class OwnershipTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @admin = users(:one)
    @member = users(:member)
    @member_token = @member.access_tokens.build(permission: "full_access", description: "member")
    @member_token.save!
    @raw_member_token = @member_token.raw_token
    @admin_workspace = @account.workspaces.create!(name: "Admin's", created_by: @admin)
    @member_workspace = @account.workspaces.create!(name: "Member's", created_by: @member)
  end

  # --- creator is recorded ---------------------------------------------------

  test "web, REST and MCP all record who created a memory or workspace" do
    sign_in_as(@member)
    post workspaces_url, params: {workspace: {name: "From the web"}}
    assert_equal @member, Workspace.find_by!(name: "From the web").created_by

    post workspace_memories_url(@member_workspace), params: {memory: {title: "Web memory"}}
    assert_equal @member, Memory.find_by!(title: "Web memory").created_by

    post workspace_memories_url(@member_workspace, format: :json),
      params: {memory: {title: "REST memory"}},
      headers: auth_headers(@raw_member_token)
    assert_equal @member, Memory.find_by!(title: "REST memory").created_by

    memory = Mcp::Tools.create_memory(@account, {"workspace_id" => @member_workspace.id.to_s, "title" => "MCP memory", "content" => "x"}, user: @member)
    assert_equal @member, Memory.find(memory[:id]).created_by
  end

  test "a new workspace's map belongs to whoever created the workspace" do
    assert_equal @member, @member_workspace.starter_map.created_by
  end

  test "the creator is shown on the workspace and the memory" do
    memory = Memory.create_with_content(@member_workspace, title: "Shown", content: "x", created_by: @member)
    sign_in_as(@admin)

    get workspace_url(@member_workspace)
    assert_match I18n.t("ownership.created_by", name: "Bob"), response.body

    get workspace_memory_url(@member_workspace, memory)
    assert_match I18n.t("ownership.created_by", name: "Bob"), response.body
  end

  test "an item with no recorded creator shows the account admin" do
    sign_in_as(@admin)

    get workspace_url(workspaces(:one))
    assert_match I18n.t("ownership.created_by", name: I18n.t("ownership.account_admin")), response.body
  end

  # --- workspaces -------------------------------------------------------------

  test "a member cannot delete, archive or permanently delete someone else's workspace" do
    sign_in_as(@member)

    delete workspace_url(@admin_workspace)
    assert_response :see_other
    assert_not @admin_workspace.reload.deleted?

    post archive_workspace_url(@admin_workspace)
    assert_response :see_other
    assert_not @admin_workspace.reload.archived?

    @admin_workspace.soft_delete
    delete destroy_deleted_workspace_url(@admin_workspace)
    assert_response :see_other
    assert Workspace.exists?(@admin_workspace.id)
  end

  test "items with no recorded creator belong to the admin" do
    sign_in_as(@member)

    delete workspace_url(workspaces(:one))
    assert_not workspaces(:one).reload.deleted?
  end

  test "a member can delete and archive their own workspace" do
    sign_in_as(@member)

    post archive_workspace_url(@member_workspace)
    assert @member_workspace.reload.archived?

    delete workspace_url(@member_workspace)
    assert @member_workspace.reload.deleted?

    delete destroy_deleted_workspace_url(@member_workspace)
    assert_not Workspace.exists?(@member_workspace.id)
  end

  test "an admin can delete anything" do
    sign_in_as(@admin)

    delete workspace_url(@member_workspace)
    assert @member_workspace.reload.deleted?
  end

  test "the menu hides what the member cannot do" do
    sign_in_as(@member)

    get workspace_url(@admin_workspace)
    assert_select "a[data-turbo-method='delete'][href=?]", workspace_path(@admin_workspace), count: 0
    assert_select "a[href=?]", archive_workspace_path(@admin_workspace), count: 0
    assert_select "a[href=?]", edit_workspace_path(@admin_workspace)

    get workspace_url(@member_workspace)
    assert_select "a[href=?]", archive_workspace_path(@member_workspace)
  end

  test "REST answers 403 for a workspace the token's owner does not own" do
    delete workspace_url(@admin_workspace, format: :json), headers: auth_headers(@raw_member_token)
    assert_response :forbidden
    assert_not @admin_workspace.reload.deleted?

    post archive_workspace_url(@admin_workspace, format: :json), headers: auth_headers(@raw_member_token)
    assert_response :forbidden
    assert_not @admin_workspace.reload.archived?

    delete workspace_url(@member_workspace, format: :json), headers: auth_headers(@raw_member_token)
    assert_response :no_content
  end

  # --- memories ---------------------------------------------------------------

  test "a member cannot delete or purge someone else's memory, at any version" do
    memory = Memory.create_with_content(@member_workspace, title: "Admin's memory", content: "v1", created_by: @admin)
    v2 = memory.create_version!(content: "v2", created_by: @member)
    memory.create_version!(content: "v3", created_by: @member)
    sign_in_as(@member)

    assert_no_difference("Memory.count") do
      delete workspace_memory_url(@member_workspace, memory)
      delete workspace_memory_url(@member_workspace, v2)
      post workspace_memory_versions_purge_url(@member_workspace, memory), params: {keep: 1, current_version_id: memory.current_version.id}
    end

    get new_workspace_memory_versions_purge_url(@member_workspace, memory)
    assert_response :see_other

    get workspace_memory_url(@member_workspace, memory)
    assert_select "a[data-turbo-method='delete'][href=?]", workspace_memory_path(@member_workspace, memory), count: 0
    assert_select "a[href=?]", new_workspace_memory_versions_purge_path(@member_workspace, memory), count: 0
  end

  test "a member can delete their own memory, taking every version with it" do
    memory = Memory.create_with_content(@member_workspace, title: "Mine", content: "v1", created_by: @member)
    memory.create_version!(content: "v2")
    sign_in_as(@member)

    assert_difference("Memory.count", -2) do
      delete workspace_memory_url(@member_workspace, memory)
    end
  end

  test "REST answers 403 for a memory the token's owner does not own" do
    memory = Memory.create_with_content(@member_workspace, title: "Admin's memory", content: "v1", created_by: @admin)

    assert_no_difference("Memory.count") do
      delete workspace_memory_url(@member_workspace, memory, format: :json), headers: auth_headers(@raw_member_token)
    end
    assert_response :forbidden
  end

  test "MCP exposes no tool that deletes, archives or purges" do
    names = Mcp::ToolDefinitions::ALL.map { |tool| tool[:name] } if defined?(Mcp::ToolDefinitions::ALL)
    names ||= Mcp::Tools.singleton_methods.map(&:to_s)

    assert_empty names.grep(/delete|destroy|purge|archive/)
  end

  # --- explanation ------------------------------------------------------------

  test "the rule is explained where people invite others" do
    sign_in_as(@admin)

    get account_url
    assert_match I18n.t("accounts.invitations.permissions"), response.body
  end
end
