require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "requires name" do
    workspace = Workspace.new(name: "", account: accounts(:one))
    assert_not workspace.valid?
    assert workspace.errors[:name].any?
  end

  test "enforces name max length" do
    workspace = Workspace.new(name: "a" * 101, account: accounts(:one))
    assert_not workspace.valid?
    assert workspace.errors[:name].any?
  end

  test "belongs to account" do
    assert_equal accounts(:one), workspaces(:one).account
  end

  test "status returns :active for normal workspace" do
    assert_equal :active, workspaces(:one).status
  end

  test "status returns :archived" do
    assert_equal :archived, workspaces(:archived).status
  end

  test "status returns :deleted" do
    assert_equal :deleted, workspaces(:deleted).status
  end

  test "soft_delete sets deleted_at" do
    workspace = workspaces(:one)
    workspace.soft_delete
    assert workspace.deleted_at.present?
  end

  test "restore clears deleted_at" do
    workspace = workspaces(:deleted)
    workspace.restore
    assert_nil workspace.deleted_at
  end

  test "search finds by name" do
    results = Workspace.search("Project")
    assert_includes results, workspaces(:one)
  end

  # -- ordered_with_pins_first --

  test "ordered_with_pins_first default puts pinned first then updated_at desc" do
    user = users(:one)
    account = accounts(:one)

    # workspaces(:one) is pinned for user one (see pins fixture).
    older = account.workspaces.create!(name: "Zeta Unpinned", updated_at: 2.days.ago)
    newer = account.workspaces.create!(name: "Alpha Unpinned", updated_at: 1.hour.ago)

    result = account.workspaces.active.ordered_with_pins_first(user).to_a

    # Pinned workspace comes first.
    assert_equal workspaces(:one), result.first

    # Unpinned ordered by updated_at desc: newer before older.
    assert_operator result.index(newer), :<, result.index(older)
  end

  test "ordered_with_pins_first with sort name orders unpinned alphabetically, pins still first" do
    user = users(:one)
    account = accounts(:one)

    account.workspaces.create!(name: "Banana")
    account.workspaces.create!(name: "Apple")

    result = account.workspaces.active.ordered_with_pins_first(user, sort: "name").to_a

    # Pinned workspace is always first regardless of name.
    assert_equal workspaces(:one), result.first

    unpinned_names = result.reject { |w| w == workspaces(:one) }.map(&:name)
    assert_equal unpinned_names.sort_by(&:downcase), unpinned_names
  end

  test "ordered_with_pins_first with sort memories orders unpinned by memories_count desc" do
    user = users(:one)
    account = accounts(:one)

    many = account.workspaces.create!(name: "Many Memories")
    few = account.workspaces.create!(name: "Few Memories")
    many.update_column(:memories_count, 10)
    few.update_column(:memories_count, 2)

    result = account.workspaces.active.ordered_with_pins_first(user, sort: "memories").to_a

    assert_equal workspaces(:one), result.first
    assert_operator result.index(many), :<, result.index(few)
  end

  # -- last_activity --

  test "last_activity returns latest memory created_at" do
    workspace = workspaces(:one)
    latest = workspace.memories.maximum(:created_at)
    assert_equal latest, workspace.last_activity
  end

  test "last_activity returns created_at when no memories" do
    workspace = accounts(:one).workspaces.create!(name: "Empty Workspace")
    assert_equal workspace.created_at, workspace.last_activity
  end

  test "last_activity returns a Time when loaded via select alias" do
    workspace = accounts(:one).workspaces
      .select(<<~SQL.squish)
        workspaces.*,
        (SELECT MAX(memories.created_at) FROM memories WHERE memories.workspace_id = workspaces.id) AS last_activity_at
      SQL
      .find(workspaces(:one).id)

    assert workspace.has_attribute?(:last_activity_at)
    assert_kind_of Time, workspace.last_activity
  end
end
