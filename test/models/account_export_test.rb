require "test_helper"

class AccountExportTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @admin = users(:one)
  end

  test "exports_this_month returns only exports from current calendar month" do
    # Fixtures created_at defaults to now (current month)
    this_month = @account.account_exports.exports_this_month
    assert this_month.any?
    this_month.each do |export|
      assert_equal Time.current.month, export.created_at.month
      assert_equal Time.current.year, export.created_at.year
    end
  end

  test "expired? returns true when expires_at is in the past" do
    export = account_exports(:expired_export)
    assert export.expired?
  end

  test "downloadable? returns true only when completed, not expired, and archive attached" do
    export = account_exports(:completed_export)
    refute export.downloadable?, "Should not be downloadable without archive attached"

    export.archive.attach(
      io: StringIO.new("fake zip data"),
      filename: "export.zip",
      content_type: "application/zip"
    )
    assert export.downloadable?
  end

  test "validates presence of account and user" do
    export = AccountExport.new(status: "pending")
    refute export.valid?
    assert export.errors[:account].any?
    assert export.errors[:user].any?
  end

  test "validates status inclusion in allowed values" do
    export = AccountExport.new(account: @account, user: @admin, status: "invalid")
    refute export.valid?
    assert export.errors[:status].any?
  end

  test "MONTHLY_LIMIT constant equals 2" do
    assert_equal 2, AccountExport::MONTHLY_LIMIT
  end
end
