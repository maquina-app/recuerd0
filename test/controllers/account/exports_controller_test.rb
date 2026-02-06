require "test_helper"

class Account::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:member)
    @account = accounts(:one)
  end

  test "create enqueues export job and redirects with notice for admin" do
    sign_in_as(@admin)

    # Clear existing exports for clean count
    @account.account_exports.delete_all

    assert_enqueued_with(job: Accounts::ExportJob) do
      post account_exports_url
    end

    assert_redirected_to account_path
    follow_redirect!
    assert_equal "Your data export has been started. You'll receive an email when it's ready.", flash[:notice]
  end

  test "create rejects when monthly limit exceeded" do
    sign_in_as(@admin)

    # Clear and create exactly MONTHLY_LIMIT exports
    @account.account_exports.delete_all
    AccountExport::MONTHLY_LIMIT.times do
      @account.account_exports.create!(user: @admin, status: "pending")
    end

    assert_no_enqueued_jobs(only: Accounts::ExportJob) do
      post account_exports_url
    end

    assert_redirected_to account_path
    follow_redirect!
    assert_equal "You've reached the maximum of 2 exports per month.", flash[:alert]
  end

  test "create rejects non-admin users" do
    sign_in_as(@member)

    assert_no_enqueued_jobs(only: Accounts::ExportJob) do
      post account_exports_url
    end

    assert_redirected_to account_path
  end

  test "show streams file directly for downloadable export" do
    sign_in_as(@admin)

    export = @account.account_exports.create!(
      user: @admin,
      status: "completed",
      completed_at: 1.day.ago,
      expires_at: 4.days.from_now
    )
    export.archive.attach(
      io: StringIO.new("fake zip data"),
      filename: "test-export.zip",
      content_type: "application/zip"
    )

    get account_export_url(export)
    assert_response :success
    assert_equal "application/zip", response.content_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_equal "fake zip data", response.body
  end

  test "show redirects to account_path with alert for expired export" do
    sign_in_as(@admin)

    export = @account.account_exports.create!(
      user: @admin,
      status: "completed",
      completed_at: 10.days.ago,
      expires_at: 2.days.ago
    )

    get account_export_url(export)
    assert_redirected_to account_path
  end

  test "show rejects non-admin users" do
    sign_in_as(@member)

    export = @account.account_exports.create!(
      user: @admin,
      status: "completed",
      completed_at: 1.day.ago,
      expires_at: 4.days.from_now
    )
    export.archive.attach(
      io: StringIO.new("fake zip data"),
      filename: "test-export.zip",
      content_type: "application/zip"
    )

    get account_export_url(export)
    assert_redirected_to account_path
  end

  test "show requires authentication" do
    export = account_exports(:completed_export)
    get account_export_url(export)
    assert_redirected_to new_session_url
  end
end
