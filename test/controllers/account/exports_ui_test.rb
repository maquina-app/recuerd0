require "test_helper"

class Account::ExportsUITest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @member = users(:member)
    @account = accounts(:one)
  end

  test "admin sees export card on account page" do
    sign_in_as(@admin)
    get account_url

    assert_response :success
    assert_match "Data Export", response.body
  end

  test "export button disabled when monthly limit reached" do
    sign_in_as(@admin)

    @account.account_exports.delete_all
    AccountExport::MONTHLY_LIMIT.times do
      @account.account_exports.create!(
        user: @admin,
        status: "completed",
        completed_at: 1.day.ago,
        expires_at: 4.days.from_now
      )
    end

    get account_url
    assert_response :success
    assert_select "button[disabled]"
  end

  test "download link visible when completed export exists" do
    sign_in_as(@admin)

    @account.account_exports.delete_all
    export = @account.account_exports.create!(
      user: @admin,
      status: "completed",
      completed_at: 1.day.ago,
      expires_at: 4.days.from_now
    )
    export.archive.attach(
      io: StringIO.new("fake zip"),
      filename: "export.zip",
      content_type: "application/zip"
    )

    get account_url
    assert_response :success
    assert_select "a[href=?]", account_export_path(export)
  end

  test "member does not see export card" do
    sign_in_as(@member)
    get account_url

    assert_response :success
    refute_match "Data Export", response.body
  end
end
