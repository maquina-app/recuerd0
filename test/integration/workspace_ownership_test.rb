require "test_helper"

# The owner answers for a thing and the creator stays on the record. A workspace's owner
# also controls what is deleted from it.
class WorkspaceOwnershipTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @admin = users(:one)
    @member = users(:member)
    @other_member = @account.users.create!(email_address: "other@example.com", password: "password", role: "member")
    @member_workspace = @account.workspaces.create!(name: "Member's", created_by: @member)
    @admin_workspace = @account.workspaces.create!(name: "Admin's", created_by: @admin)
  end

  def token_for(user, permission: "full_access")
    token = user.access_tokens.build(permission:, description: "test")
    token.save!
    auth_headers(token.raw_token)
  end

  # --- editing a workspace -----------------------------------------------------

  test "a member cannot rename or redescribe a workspace someone else owns" do
    sign_in_as(@member)

    get edit_workspace_url(@admin_workspace)
    assert_redirected_to workspaces_url

    patch workspace_url(@admin_workspace), params: {workspace: {name: "Renamed", description: "Changed"}}
    assert_equal I18n.t("ownership.denied"), flash[:alert]
    assert_equal "Admin's", @admin_workspace.reload.name
    assert_nil @admin_workspace.description

    patch workspace_url(@admin_workspace, format: :json), params: {workspace: {name: "Renamed"}}, headers: token_for(@member)
    assert_response :forbidden
    assert_equal "Admin's", @admin_workspace.reload.name
  end

  test "someone who can't edit a workspace isn't offered the description link" do
    sign_in_as(@member)

    get workspace_url(@admin_workspace)
    assert_select "a[href=?]", edit_workspace_path(@admin_workspace), count: 0
    assert_match I18n.t("workspaces.show.no_description"), response.body
  end

  test "the owner and an admin can edit it, and a workspace with no owner is the admin's" do
    sign_in_as(@member)
    patch workspace_url(@member_workspace), params: {workspace: {name: "Renamed by owner"}}
    assert_equal "Renamed by owner", @member_workspace.reload.name
    delete session_url

    unowned = @account.workspaces.create!(name: "No owner")
    sign_in_as(@admin)
    patch workspace_url(@member_workspace), params: {workspace: {name: "Renamed by admin"}}
    patch workspace_url(unowned), params: {workspace: {name: "Renamed too"}}
    assert_equal "Renamed by admin", @member_workspace.reload.name
    assert_equal "Renamed too", unowned.reload.name
  end

  # --- a workspace's owner and what is in it ------------------------------------

  test "a workspace's owner can delete anyone's memory in it, on web and REST" do
    admins = Memory.create_with_content(@member_workspace, title: "Admin's", content: "x", created_by: @admin)
    thirds = Memory.create_with_content(@member_workspace, title: "Third's", content: "x", created_by: @other_member)
    sign_in_as(@member)

    get workspace_memory_url(@member_workspace, admins)
    assert_select "a[data-turbo-method='delete'][href=?], a[data-turbo-method='delete'][href=?]",
      workspace_memory_path(@member_workspace, admins), workspace_memory_path(@member_workspace, admins)

    delete workspace_memory_url(@member_workspace, admins)
    assert_not Memory.exists?(admins.id)

    delete workspace_memory_url(@member_workspace, thirds, format: :json), headers: token_for(@member)
    assert_response :no_content
    assert_not Memory.exists?(thirds.id)
  end

  test "it does not work the other way, or for another member" do
    theirs = Memory.create_with_content(@admin_workspace, title: "Member's", content: "x", created_by: @member)
    admins = Memory.create_with_content(@admin_workspace, title: "Admin's", content: "x", created_by: @admin)

    delete workspace_memory_url(@admin_workspace, admins, format: :json), headers: token_for(@member)
    assert_response :forbidden

    delete workspace_memory_url(@admin_workspace, theirs, format: :json), headers: token_for(@other_member)
    assert_response :forbidden

    assert Memory.exists?(admins.id)
    assert Memory.exists?(theirs.id)
  end

  test "a workspace with no owner gives nobody but an admin that power" do
    unowned = @account.workspaces.create!(name: "No owner")
    memory = Memory.create_with_content(unowned, title: "Member's", content: "x", created_by: @other_member)

    delete workspace_memory_url(unowned, memory, format: :json), headers: token_for(@member)

    assert_response :forbidden
  end

  test "overwriting and purging someone else's memory stay with its owner and admins" do
    memory = Memory.create_with_content(@member_workspace, title: "Admin's", content: "v1", created_by: @admin)
    memory.create_version!(content: "v2", created_by: @admin)
    sign_in_as(@member)

    patch workspace_memory_url(@member_workspace, memory, format: :json), params: {memory: {title: "Overwritten"}}, headers: token_for(@member)
    assert_response :forbidden

    assert_no_difference("Memory.count") do
      post workspace_memory_versions_purge_url(@member_workspace, memory), params: {keep: 1, current_version_id: memory.current_version.id}
    end
  end

  test "a soft delete says when other people's memories are included" do
    Memory.create_with_content(@member_workspace, title: "Admin's", content: "x", created_by: @admin)
    Memory.create_with_content(@member_workspace, title: "Third's", content: "x", created_by: @other_member)
    sign_in_as(@member)

    get workspace_url(@member_workspace)

    confirm = css_select("a[data-turbo-method='delete'][href='#{workspace_path(@member_workspace)}']").first["data-turbo-confirm"]
    assert_includes confirm, I18n.t("workspaces.actions.confirm.includes_others", count: 2)
  end

  test "no warning when everything is the person's own" do
    sign_in_as(@member)

    get workspace_url(@member_workspace)

    confirm = css_select("a[data-turbo-method='delete'][href='#{workspace_path(@member_workspace)}']").first["data-turbo-confirm"]
    assert_not_includes confirm, "belonging to"
  end

  # --- removing someone ---------------------------------------------------------

  test "a removed user's work passes to the first admin by default, and keeps its creator" do
    memory = Memory.create_with_content(@admin_workspace, title: "Member's", content: "x", created_by: @member)
    version = memory.create_version!(content: "v2", created_by: @member)
    sign_in_as(@admin)

    delete account_user_url(@member)

    assert_equal @admin, @member_workspace.reload.owner
    assert_equal @admin, memory.reload.owner
    assert_equal @member, memory.created_by
    assert_equal @member, version.reload.created_by

    get workspace_memory_url(@admin_workspace, memory)
    assert_match "Owned by you, created by a former member", response.body
  end

  test "the admin can choose who receives it" do
    sign_in_as(@admin)

    delete account_user_url(@member), params: {transfer_to: @other_member.id}

    assert_equal @other_member, @member_workspace.reload.owner
  end

  test "work can't go to the person leaving, a former member, or another account" do
    @other_member.anonymize_email!
    sign_in_as(@admin)

    [@member.id, @other_member.id, users(:two).id].each do |id|
      delete account_user_url(@member), params: {transfer_to: id}
      assert_equal I18n.t("ownership.invalid_recipient"), flash[:alert]
    end

    assert_not @member.reload.anonymized?
    assert_equal @member, @member_workspace.reload.owner
  end

  test "the dialog says what the person owns and preselects the first admin" do
    Memory.create_with_content(@admin_workspace, title: "Member's", content: "x", created_by: @member)
    sign_in_as(@admin)

    get account_url

    assert_match "They own 1 workspace and 2 memories.", response.body
    assert_select "select[name='transfer_to'] option[selected][value=?]", @admin.id.to_s
  end

  test "the dialog doesn't ask when the person owns nothing" do
    sign_in_as(@admin)

    get account_url

    assert_select "#%s" % ActionView::RecordIdentifier.dom_id(@other_member, :transfer_to), count: 0
  end

  # --- passing and taking --------------------------------------------------------

  test "the owner can pass a workspace, which moves the workspace only" do
    memory = Memory.create_with_content(@member_workspace, title: "Mine", content: "x", created_by: @member)
    updated_at = @member_workspace.reload.updated_at
    sign_in_as(@member)

    get edit_workspace_ownership_url(@member_workspace)
    assert_response :success
    assert_select "select[name='user_id'] option[value=?]", @other_member.id.to_s
    assert_select "select[name='user_id'] option[value=?]", @member.id.to_s, count: 0

    patch workspace_ownership_url(@member_workspace), params: {user_id: @other_member.id}
    assert_response :see_other

    assert_equal @other_member, @member_workspace.reload.owner
    assert_equal @member, @member_workspace.created_by
    assert_equal @member, memory.reload.owner
    assert_equal updated_at, @member_workspace.updated_at, "a handover is not activity"
  end

  test "the owner can pass a memory from any of its versions, and the new owner has the rights" do
    memory = Memory.create_with_content(@admin_workspace, title: "Mine", content: "x", created_by: @member)
    version = memory.create_version!(content: "v2", created_by: @member)
    sign_in_as(@member)

    patch workspace_memory_ownership_url(@admin_workspace, version), params: {user_id: @other_member.id}
    assert_equal @other_member, memory.reload.owner
    assert_nil version.reload.owner_id

    patch workspace_memory_url(@admin_workspace, memory, format: :json), params: {memory: {title: "Old owner"}}, headers: token_for(@member)
    assert_response :forbidden

    patch workspace_memory_url(@admin_workspace, memory, format: :json), params: {memory: {title: "New owner"}}, headers: token_for(@other_member)
    assert_response :success

    delete workspace_memory_url(@admin_workspace, memory, format: :json), headers: token_for(@other_member)
    assert_response :no_content
  end

  test "an admin can take something, and passes it on only as its owner" do
    sign_in_as(@admin)

    patch workspace_ownership_url(@member_workspace), params: {user_id: @other_member.id}
    assert_equal I18n.t("ownership.pass_denied"), flash[:alert]
    assert_equal @member, @member_workspace.reload.owner

    patch workspace_ownership_url(@member_workspace), params: {user_id: @admin.id}
    assert_equal @admin, @member_workspace.reload.owner

    patch workspace_ownership_url(@member_workspace), params: {user_id: @other_member.id}
    assert_equal @other_member, @member_workspace.reload.owner
  end

  test "anyone else is refused, on web and REST" do
    sign_in_as(@other_member)

    get edit_workspace_ownership_url(@member_workspace)
    assert_equal I18n.t("ownership.pass_denied"), flash[:alert]

    patch workspace_ownership_url(@member_workspace), params: {user_id: @other_member.id}
    assert_equal I18n.t("ownership.pass_denied"), flash[:alert]
    assert_equal @member, @member_workspace.reload.owner
    delete session_url

    patch workspace_ownership_url(@member_workspace, format: :json), params: {user_id: @other_member.id}, headers: token_for(@other_member)
    assert_response :forbidden

    memory = Memory.create_with_content(@member_workspace, title: "Mine", content: "x", created_by: @member)
    patch workspace_memory_ownership_url(@member_workspace, memory, format: :json), params: {user_id: @other_member.id}, headers: token_for(@other_member)
    assert_response :forbidden
    assert_equal @member, memory.reload.owner
  end

  test "REST can pass and answers with the new owner" do
    patch workspace_ownership_url(@member_workspace, format: :json), params: {user_id: @other_member.id}, headers: token_for(@member)

    assert_response :success
    assert_equal({"id" => @member_workspace.id, "owner_id" => @other_member.id}, response.parsed_body)
  end

  test "a read-only token cannot pass anything" do
    patch workspace_ownership_url(@member_workspace, format: :json), params: {user_id: @other_member.id}, headers: token_for(@member, permission: "read_only")

    assert_response :forbidden
    assert_equal @member, @member_workspace.reload.owner
  end

  test "ownership can't go to a former member, another account, or the owner again" do
    @other_member.anonymize_email!

    [@other_member.id, users(:two).id, @member.id, 0].each do |id|
      patch workspace_ownership_url(@member_workspace, format: :json), params: {user_id: id}, headers: token_for(@member)
      assert_response :unprocessable_entity
    end

    assert_equal @member, @member_workspace.reload.owner
  end

  test "a deleted workspace has to come back before it changes hands" do
    @member_workspace.soft_delete

    patch workspace_ownership_url(@member_workspace, format: :json), params: {user_id: @other_member.id}, headers: token_for(@member)

    assert_response :not_found
    assert_equal @member, @member_workspace.reload.owner
  end

  test "the menu offers the owner Pass and an admin Take" do
    sign_in_as(@member)
    get workspace_url(@member_workspace)
    assert_select "a[href=?]", edit_workspace_ownership_path(@member_workspace)
    assert_select "a[data-turbo-method='patch']", count: 0
    get workspace_url(@admin_workspace)
    assert_select "a[href=?]", edit_workspace_ownership_path(@admin_workspace), count: 0
    delete session_url

    sign_in_as(@admin)
    get workspace_url(@member_workspace)
    assert_select "a[data-turbo-method='patch'][href=?]", workspace_ownership_path(@member_workspace, user_id: @admin.id)
  end

  test "JSON reports the owner, and a handover changes the validator" do
    headers = token_for(@member)

    get workspace_url(@member_workspace, format: :json), headers: headers
    assert_equal @member.id, response.parsed_body["owner_id"]
    etag = response.headers["ETag"]

    @member_workspace.pass_ownership_to(@other_member)

    get workspace_url(@member_workspace, format: :json), headers: headers.merge("If-None-Match" => etag)
    assert_response :success
    assert_equal @other_member.id, response.parsed_body["owner_id"]
  end

  # --- seeing what you own ------------------------------------------------------

  test "the new owner can see what they now own" do
    memory = Memory.create_with_content(@admin_workspace, title: "Handed over", content: "x", created_by: @member)
    version = memory.create_version!(title: "Handed over, latest", content: "v2", created_by: @member)
    memory.pass_ownership_to(@other_member)
    @member_workspace.pass_ownership_to(@other_member)
    sign_in_as(@other_member)

    get profile_url
    assert_select "a[href=?]", profile_ownership_path

    get profile_ownership_url
    assert_response :success
    assert_select "a[href=?]", workspace_path(@member_workspace)
    assert_select "a", text: version.title
    assert_select "a", text: "Handed over", count: 0
  end

  test "someone who owns nothing is told so, and a deleted workspace stays out of the list" do
    @member_workspace.pass_ownership_to(@other_member)
    @member_workspace.soft_delete
    sign_in_as(@other_member)

    get profile_ownership_url

    assert_select "a[href=?]", deleted_workspace_path(@member_workspace), count: 0
    assert_match I18n.t("profile.ownerships.show.no_workspaces").gsub("'", "&#39;"), response.body
  end

  test "an admin's list includes what has no owner, in their own account only" do
    unowned = @account.workspaces.create!(name: "No owner")
    elsewhere = accounts(:two).workspaces.create!(name: "Elsewhere")

    assert_includes @admin.owned_workspaces, unowned
    assert_not_includes @admin.owned_workspaces, elsewhere
    assert_not_includes @member.owned_workspaces, unowned
  end

  test "the label stays simple until owner and creator differ" do
    sign_in_as(@member)

    get workspace_url(@member_workspace)
    assert_match "Created by you", response.body
    assert_no_match(/Owned by/, response.body)
  end
end
