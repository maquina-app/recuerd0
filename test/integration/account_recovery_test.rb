require "test_helper"

class AccountRecoveryTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:one)
    @admin = users(:one)
    @member = users(:member)
  end

  test "deleting then signing in reaches recovery, and restore brings everything back" do
    @account.account_exports.destroy_all
    sign_in_as(@admin)
    delete account_url, params: {password: "password"}
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match "scheduled for deletion", response.body

    post session_url, params: {email_address: @admin.email_address, password: "password"}
    follow_redirect!
    assert_redirected_to account_recovery_path
    follow_redirect!
    assert_response :success
    assert_match I18n.l(@account.reload.permanent_deletion_on, format: :long), response.body
    assert_select "form[action=?]", account_recovery_path
    assert_select "form[action=?]", account_exports_path

    post account_recovery_url
    assert_redirected_to workspaces_path
    assert_not @account.reload.deleted?

    follow_redirect!
    assert_response :success
  end

  test "the email cannot register a new account during the grace period" do
    @account.schedule_deletion!

    assert_no_difference("Account.count") do
      post registration_url, params: {user: {email_address: @admin.email_address, password: "password123", password_confirmation: "password123"}}
    end
    assert_response :unprocessable_entity
    assert_select "[data-form-part='error'] a[href=?]", new_session_path
  end

  test "a finished export can still be downloaded from the recovery page" do
    export = @account.account_exports.create!(user: @admin, status: "completed", completed_at: Time.current, expires_at: 5.days.from_now)
    export.archive.attach(io: StringIO.new("zip"), filename: "export.zip", content_type: "application/zip")
    @account.schedule_deletion!

    sign_in_as(@admin)
    get account_recovery_url
    assert_select "a[href=?]", account_export_path(export)

    get account_export_url(export)
    assert_response :success
    assert_equal "zip", response.body
  end

  test "a member is told what happened but cannot restore" do
    @account.schedule_deletion!

    sign_in_as(@member)
    get account_recovery_url
    assert_response :success
    assert_select "form[action=?]", account_recovery_path, count: 0

    post account_recovery_url
    assert_redirected_to account_recovery_path
    assert @account.reload.deleted?
  end

  test "signing out works from the recovery page" do
    @account.schedule_deletion!
    sign_in_as(@admin)

    delete session_url
    assert_redirected_to new_session_path

    get account_recovery_url
    assert_redirected_to new_session_path
  end

  test "the recovery page does not exist for a live account" do
    sign_in_as(@admin)

    get account_recovery_url
    assert_redirected_to workspaces_path
  end

  test "tokens are refused during the grace period, on REST and MCP" do
    @account.schedule_deletion!

    get workspaces_url(format: :json), headers: auth_headers("test_full_token_456")
    assert_response :unauthorized

    post mcp_endpoint_url,
      params: {jsonrpc: "2.0", id: 1, method: "tools/list"}.to_json,
      headers: auth_headers("test_full_token_456").merge("Content-Type" => "application/json")
    assert_response :unauthorized
  end
end
