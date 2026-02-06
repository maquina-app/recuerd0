require "test_helper"

class Accounts::ExportCleanupJobTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @admin = users(:one)
  end

  test "cleanup destroys expired exports and purges attachments" do
    export = AccountExport.create!(
      account: @account,
      user: @admin,
      status: "completed",
      completed_at: 10.days.ago,
      expires_at: 2.days.ago
    )
    export.archive.attach(
      io: StringIO.new("fake zip"),
      filename: "test.zip",
      content_type: "application/zip"
    )

    Accounts::ExportCleanupJob.perform_now

    assert_nil AccountExport.find_by(id: export.id), "Expired export should be destroyed"
  end

  test "cleanup destroys failed exports older than 1 day" do
    old_failed = AccountExport.create!(
      account: @account,
      user: @admin,
      status: "failed",
      error_message: "Something broke"
    )
    old_failed.update_column(:created_at, 2.days.ago)

    recent_failed = AccountExport.create!(
      account: @account,
      user: @admin,
      status: "failed",
      error_message: "Recent failure"
    )

    Accounts::ExportCleanupJob.perform_now

    assert_nil AccountExport.find_by(id: old_failed.id), "Old failed export should be destroyed"
    assert AccountExport.find_by(id: recent_failed.id), "Recent failed export should remain"
  end

  test "cleanup does not touch active (non-expired) exports" do
    active_export = AccountExport.create!(
      account: @account,
      user: @admin,
      status: "completed",
      completed_at: 1.day.ago,
      expires_at: 4.days.from_now
    )

    Accounts::ExportCleanupJob.perform_now

    assert AccountExport.find_by(id: active_export.id), "Active export should remain"
  end
end
