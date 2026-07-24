require "test_helper"
require Rails.root.join("db/migrate/20260724000000_backfill_inactive_workspace_pins")

class BackfillInactiveWorkspacePinsTest < ActiveSupport::TestCase
  test "removes lingering inactive workspace pins and is idempotent" do
    inactive_workspace = workspaces(:one)
    inactive_workspace.pin!(users(:member))
    inactive_workspace.update_column(:archived_at, Time.current)

    active_workspace = workspaces(:two)
    active_workspace.pin!(users(:two))

    migration = BackfillInactiveWorkspacePins.new

    assert_difference -> { Pin.count }, -2 do
      migration.up
    end

    assert_empty inactive_workspace.pins.reload
    assert active_workspace.pins.reload.exists?
    assert pins(:memory_pin).reload.persisted?

    assert_no_difference -> { Pin.count } do
      migration.up
    end
  end
end
