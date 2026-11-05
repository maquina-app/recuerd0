require "test_helper"

class TeamAccessTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @admin = users(:one)
    @member = users(:member)
    @member_workspace = @account.workspaces.create!(name: "Member's", created_by: @member)
    @admin_workspace = @account.workspaces.create!(name: "Admin's", created_by: @admin)
  end

  def member_token(permission: "full_access")
    token = @member.access_tokens.build(permission:, description: "member")
    token.save!
    token.raw_token
  end

  # --- removing a member -------------------------------------------------------

  test "removing a member cuts off their tokens on REST and MCP, and their OAuth grants" do
    raw = member_token
    client = OauthClient.create!(client_name: "Claude", redirect_uris: JSON.generate(["https://claude.ai/cb"]))
    oauth = @member.access_tokens.build(permission: "full_access", oauth_client: client, audience: "http://www.example.com/mcp", expires_at: 1.hour.from_now)
    oauth.assign_refresh_token!
    oauth.save!
    code = client.oauth_authorization_codes.create!(user: @member, code: "code", code_challenge: "x", redirect_uri: "https://claude.ai/cb", expires_at: 10.minutes.from_now)

    get workspaces_url(format: :json), headers: auth_headers(raw)
    assert_response :success

    sign_in_as(@admin)
    delete account_user_url(@member)
    delete session_url

    get workspaces_url(format: :json), headers: auth_headers(raw)
    assert_response :unauthorized

    assert_no_difference("Memory.count") do
      post workspace_memories_url(@member_workspace, format: :json), params: {memory: {title: "After removal"}}, headers: auth_headers(raw)
    end
    assert_response :unauthorized

    post mcp_endpoint_url,
      params: {jsonrpc: "2.0", id: 1, method: "tools/list"}.to_json,
      headers: auth_headers(oauth.raw_token).merge("Content-Type" => "application/json")
    assert_response :unauthorized

    assert_nil AccessToken.find_by_refresh_token(oauth.raw_refresh_token)
    assert_not OauthAuthorizationCode.exists?(code.id)
  end

  test "the removal dialog says what it does, once" do
    sign_in_as(@admin)

    get account_url

    confirm = css_select("[data-turbo-confirm]").map { |node| node["data-turbo-confirm"] }.find { |text| text.include?("API tokens") }
    assert confirm
    assert_no_match(/Remove/, confirm)
  end

  # --- permanent deletion ------------------------------------------------------

  test "a member cannot permanently delete their workspace once it holds someone else's memory" do
    memory = Memory.create_with_content(@member_workspace, title: "Admin's", content: "x", created_by: @admin)
    @member_workspace.soft_delete
    sign_in_as(@member)

    get deleted_workspaces_url
    assert_select "a[data-turbo-method='delete'][href=?]", destroy_deleted_workspace_path(@member_workspace), count: 0
    assert_match ERB::Util.html_escape(I18n.t("ownership.holds_others")), response.body
    assert_select "a[href=?]", restore_deleted_workspace_path(@member_workspace)

    delete destroy_deleted_workspace_url(@member_workspace)
    assert_response :see_other
    assert_equal I18n.t("ownership.holds_others"), flash[:alert]
    assert Workspace.exists?(@member_workspace.id)
    assert Memory.exists?(memory.id)
  end

  test "a memory with no recorded creator counts as someone else's" do
    Memory.create_with_content(@member_workspace, title: "Unrecorded", content: "x")
    @member_workspace.soft_delete
    sign_in_as(@member)

    delete destroy_deleted_workspace_url(@member_workspace)
    assert Workspace.exists?(@member_workspace.id)
  end

  test "a member can permanently delete a workspace holding only their own memories" do
    memory = Memory.create_with_content(@member_workspace, title: "Mine", content: "x", created_by: @member)
    memory.create_version!(content: "v2", created_by: @admin)
    @member_workspace.soft_delete
    sign_in_as(@member)

    delete destroy_deleted_workspace_url(@member_workspace)
    assert_not Workspace.exists?(@member_workspace.id)
  end

  test "an admin can permanently delete a workspace holding anyone's memories" do
    Memory.create_with_content(@member_workspace, title: "Member's", content: "x", created_by: @member)
    @member_workspace.soft_delete
    sign_in_as(@admin)

    delete destroy_deleted_workspace_url(@member_workspace)
    assert_not Workspace.exists?(@member_workspace.id)
  end

  # --- overwriting -------------------------------------------------------------

  test "on someone else's memory a member can only save a new version" do
    memory = Memory.create_with_content(@admin_workspace, title: "Admin's", content: "original", created_by: @admin)
    sign_in_as(@member)

    get edit_workspace_memory_url(@admin_workspace, memory)
    assert_select "button[value='new_version']"
    assert_select "button[value='in_place']", count: 0

    patch workspace_memory_url(@admin_workspace, memory), params: {save_as: "in_place", memory: {content: "wiped"}}
    assert_response :see_other
    assert_equal "original", memory.reload.content.body.content

    patch workspace_memory_url(@admin_workspace, memory), params: {memory: {content: "wiped"}}
    assert_equal "original", memory.reload.content.body.content

    patch workspace_memory_url(@admin_workspace, memory), params: {save_as: "new_version", memory: {content: "added"}}
    assert_equal "original", memory.reload.content.body.content
    assert_equal "added", memory.current_version.content.body.content
  end

  test "REST and MCP refuse an in-place update on someone else's memory" do
    memory = Memory.create_with_content(@admin_workspace, title: "Admin's", content: "original", created_by: @admin)

    patch workspace_memory_url(@admin_workspace, memory, format: :json),
      params: {memory: {content: "wiped"}},
      headers: auth_headers(member_token)
    assert_response :forbidden

    error = assert_raises(Mcp::ToolError) do
      Mcp::Tools.update_memory(@account, {"memory_id" => memory.id.to_s, "content" => "wiped"}, user: @member)
    end
    assert_match "create_version", error.message
    assert_equal "original", memory.reload.content.body.content
  end

  test "the creator and an admin can still update in place" do
    mine = Memory.create_with_content(@admin_workspace, title: "Member's", content: "original", created_by: @member)

    Mcp::Tools.update_memory(@account, {"memory_id" => mine.id.to_s, "content" => "by creator"}, user: @member)
    assert_equal "by creator", mine.reload.content.body.content

    Mcp::Tools.update_memory(@account, {"memory_id" => mine.id.to_s, "content" => "by admin"}, user: @admin)
    assert_equal "by admin", mine.reload.content.body.content
  end

  # --- restore and unarchive ---------------------------------------------------

  test "a member cannot restore or unarchive a workspace they did not create" do
    sign_in_as(@member)

    @admin_workspace.archive
    get archived_workspaces_url
    assert_select "a[href=?]", archive_workspace_path(@admin_workspace), count: 0
    assert_select "button[aria-label=?]", "Actions for #{@admin_workspace.name}", count: 0
    delete archive_workspace_url(@admin_workspace)
    assert @admin_workspace.reload.archived?

    delete archive_workspace_url(@admin_workspace, format: :json), headers: auth_headers(member_token)
    assert_response :forbidden

    @admin_workspace.unarchive
    @admin_workspace.soft_delete
    post restore_deleted_workspace_url(@admin_workspace)
    assert @admin_workspace.reload.deleted?
  end

  test "a member can restore and unarchive their own, and an admin anyone's" do
    @member_workspace.archive
    sign_in_as(@member)
    delete archive_workspace_url(@member_workspace)
    assert_not @member_workspace.reload.archived?

    @member_workspace.soft_delete
    post restore_deleted_workspace_url(@member_workspace)
    assert_not @member_workspace.reload.deleted?

    delete session_url
    sign_in_as(@admin)
    @member_workspace.soft_delete
    post restore_deleted_workspace_url(@member_workspace)
    assert_not @member_workspace.reload.deleted?
  end

  # --- passwords ---------------------------------------------------------------

  test "a password reset ends every session, and says what happened to tokens" do
    sign_in_as(@member)
    get workspaces_url
    assert_response :success

    token = @member.password_reset_token
    put password_url(token), params: {password: "brand-new-pass", password_confirmation: "brand-new-pass"}

    assert_redirected_to new_session_path
    assert_match "API tokens keep working", flash[:notice]
    assert_equal 0, @member.sessions.count

    get workspaces_url
    assert_redirected_to new_session_path
  end

  test "a password reset shows the real error" do
    token = @member.password_reset_token

    get edit_password_url(token)
    assert_match I18n.t("registrations.new.password_hint"), response.body

    put password_url(token), params: {password: "short", password_confirmation: "short"}
    assert_response :unprocessable_entity
    assert_match "too short", response.body
    assert_no_match(/did not match/, response.body)

    put password_url(token), params: {password: "long-enough-1", password_confirmation: "long-enough-2"}
    assert_response :unprocessable_entity
    assert_match ERB::Util.html_escape("Passwords don't match."), response.body

    put password_url(token), params: {password: "", password_confirmation: ""}
    assert_response :unprocessable_entity
  end

  test "changing a password from Profile signs out the other sessions, not this one" do
    other = @member.sessions.create!(ip_address: "1.1.1.1", user_agent: "Other")
    sign_in_as(@member)

    patch profile_password_url, params: {current_password: "password", password: "brand-new-pass", password_confirmation: "brand-new-pass"}

    assert_not Session.exists?(other.id)
    get profile_url
    assert_response :success
  end
end
