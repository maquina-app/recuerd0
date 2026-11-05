require "test_helper"

class Accounts::PurgeDeletedJobTest < ActiveJob::TestCase
  setup do
    @account = accounts(:one)
  end

  test "removes only accounts past the grace period" do
    @account.schedule_deletion!
    expired = accounts(:two)
    expired.update_column(:deleted_at, 31.days.ago)

    Accounts::PurgeDeletedJob.perform_now

    assert Account.exists?(@account.id)
    assert_not Account.exists?(expired.id)
  end

  test "removes a workspace past retention, with its versions, links and pins" do
    workspace = @account.workspaces.create!(name: "Expired", start_with_map: "0")
    memory = Memory.create_with_content(workspace, title: "Gone", content: "v1")
    version = memory.create_version!(content: "v2")
    survivor = memories(:one)
    MemoryLink.create!(from_memory: memory, to_memory: survivor)
    memory.pin!(users(:one))
    workspace.update_column(:deleted_at, 31.days.ago)

    Accounts::PurgeDeletedJob.perform_now

    assert_not Workspace.exists?(workspace.id)
    assert_not Memory.exists?(memory.id)
    assert_not Memory.exists?(version.id)
    assert_empty survivor.reload.linked_memory_ids
    assert_not Pin.exists?(pinnable_type: "Memory", pinnable_id: memory.id)
  end

  test "keeps a workspace still inside its 30 days, and any active or archived one" do
    recent = @account.workspaces.create!(name: "Recent", start_with_map: "0")
    recent.update_column(:deleted_at, 29.days.ago)
    archived = @account.workspaces.create!(name: "Archived", start_with_map: "0")
    archived.update_column(:archived_at, 90.days.ago)
    active = @account.workspaces.create!(name: "Active", start_with_map: "0")

    Accounts::PurgeDeletedJob.perform_now

    assert Workspace.exists?(recent.id)
    assert Workspace.exists?(archived.id)
    assert Workspace.exists?(active.id)
  end

  test "one failure does not stop the rest" do
    first = @account.workspaces.create!(name: "First", start_with_map: "0")
    second = @account.workspaces.create!(name: "Second", start_with_map: "0")
    [first, second].each { |workspace| workspace.update_column(:deleted_at, 31.days.ago) }
    Workspace.class_eval do
      alias_method :__destroy_bang, :destroy!
      define_method(:destroy!) { (id == first.id) ? raise("boom") : __destroy_bang }
    end

    Accounts::PurgeDeletedJob.perform_now

    assert Workspace.exists?(first.id)
    assert_not Workspace.exists?(second.id)
  ensure
    Workspace.class_eval do
      alias_method :destroy!, :__destroy_bang
      remove_method :__destroy_bang
    end
  end
end
