require "test_helper"

class WorkspaceTest < ActiveSupport::TestCase
  test "creation adds exactly one conventions-bearing starter map" do
    workspace = accounts(:one).workspaces.create!(name: "Starter map")

    assert_equal 1, workspace.memories.count
    map = workspace.memories.sole
    assert_equal map, workspace.starter_map
    assert_equal WorkspaceStarter::TITLE, map.title
    assert_equal WorkspaceStarter::TAGS, map.tags
    assert_equal "system", map.source
    assert_predicate map, :default_pinned?
    assert_predicate map, :root_version?
    assert_equal WorkspaceStarter.content(
      base_url: Rails.application.config.x.app_base_url
    ), map.content.body.content
    assert_includes map.content.body.content, "## Your workspace\n\n## Why this shape"
    assert_not_includes map.content.body.content, StartHereContent::MAP_ROUTING_BULLETS.first
    assert_includes map.content.body.to_html, "How this workspace is kept"
    assert_not map.pinned_by?(users(:one))
  end

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

  test "archive bumps updated_at" do
    workspace = workspaces(:one)
    previous_updated_at = workspace.updated_at

    travel 1.second do
      assert workspace.archive
    end

    assert_operator workspace.reload.updated_at, :>, previous_updated_at
  end

  test "archive destroys workspace pins for every user but not memory pins" do
    workspace = workspaces(:one)
    workspace.pin!(users(:member))

    assert_difference -> { workspace.pins.count }, -2 do
      workspace.archive
    end

    assert pins(:memory_pin).reload.persisted?
  end

  test "soft_delete destroys workspace pins for every user but not memory pins" do
    workspace = workspaces(:one)
    workspace.pin!(users(:member))

    assert_difference -> { workspace.pins.count }, -2 do
      workspace.soft_delete
    end

    assert workspace.deleted?
    assert pins(:memory_pin).reload.persisted?
  end

  test "unarchive bumps updated_at" do
    workspace = workspaces(:archived)
    previous_updated_at = workspace.updated_at

    travel 1.second do
      assert workspace.unarchive
    end

    assert_operator workspace.reload.updated_at, :>, previous_updated_at
    assert_not workspace.archived?
  end

  test "restore bumps updated_at" do
    workspace = workspaces(:deleted)
    previous_updated_at = workspace.updated_at

    travel 1.second do
      workspace.restore
    end

    assert_operator workspace.reload.updated_at, :>, previous_updated_at
    assert_not workspace.deleted?
  end

  test "restore of archived and deleted workspace ends active and unarchived" do
    workspace = workspaces(:one)
    workspace.archive
    workspace.soft_delete

    workspace.restore

    assert workspace.reload.active?
    assert_not workspace.archived?
    assert_not workspace.deleted?
  end

  test "search finds by name" do
    results = Workspace.search("Project")
    assert_includes results, workspaces(:one)
  end

  # -- ordered_with_pins_first --

  test "ordered_with_pins_first still shows workspaces pinned by other users" do
    account = accounts(:one)
    # workspaces(:one) is pinned by users(:one) (Alice) via the workspace_pin fixture.
    # users(:member) (Bob) has not pinned it but must still see it.
    result = account.workspaces.active.ordered_with_pins_first(users(:member)).to_a

    assert_includes result, workspaces(:one),
      "workspace pinned by another user must remain visible"
  end

  test "ordered_with_pins_first does not put another user's pins first" do
    account = accounts(:one)
    # For Bob, workspaces(:one) is just an ordinary unpinned workspace.
    result = account.workspaces.active.ordered_with_pins_first(users(:member)).to_a
    # No CASE-0 (pinned) rows for Bob, so ordering falls through to updated_at desc.
    assert_equal result.sort_by { |w| -w.updated_at.to_i }.map(&:id), result.map(&:id)
  end

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

  test "last_activity returns the starter map created_at for a new workspace" do
    workspace = accounts(:one).workspaces.create!(name: "New Workspace")

    assert_equal workspace.memories.sole.created_at, workspace.last_activity
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
