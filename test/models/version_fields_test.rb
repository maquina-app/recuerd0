require "test_helper"

# A root row is v1 and also what filters read, so its own tags and category follow the
# current version. v1 still has to answer for what it held.
class VersionFieldsTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:one)
    @memory = Memory.create_with_content(@workspace, title: "T", content: "v1", tags: ["alpha"], category: "decision")
  end

  test "v1 keeps its tags and category after a later version changes them" do
    @memory.create_version!(tags: ["beta"], category: "discovery")
    @memory.reload

    assert_equal ["alpha"], @memory.version_tags
    assert_equal "decision", @memory.version_category
    assert_equal ["beta"], @memory.tags, "filters still read the current version's"
    assert_equal "discovery", @memory.category
  end

  test "the change from v1 to v2 is reported like any other" do
    v2 = @memory.create_version!(tags: ["beta"], category: "discovery")

    changes = v2.field_changes_from(@memory.reload)

    assert_includes changes, [:tags, ["alpha"], ["beta"]]
    assert_includes changes, [:category, "decision", "discovery"]
  end

  test "v1 keeps what it held through later versions, which keep their own" do
    v2 = @memory.create_version!(tags: ["beta"])
    v3 = @memory.create_version!(tags: ["gamma"])
    @memory.reload

    assert_equal ["alpha"], @memory.version_tags
    assert_equal ["beta"], v2.reload.version_tags
    assert_equal ["gamma"], v3.reload.version_tags
  end

  test "tags that stay the same report no change, however many versions later" do
    v2 = @memory.create_version!(content: "v2")

    assert_empty v2.field_changes_from(@memory.reload).select { |field, *| field.in?(%i[tags category]) }
  end

  test "a root from before v1's values were kept reports no change it can't know about" do
    v2 = @memory.create_version!(tags: ["beta"])
    @memory.reload.update_columns(first_version_tags: nil, first_version_category: nil)

    assert_empty v2.field_changes_from(@memory).select { |field, *| field == :tags }
  end

  test "restoring v1 brings back its tags and category" do
    @memory.create_version!(tags: ["beta"], category: "discovery")

    restored = @memory.reload.create_version!(created_by: users(:one))

    assert_equal ["alpha"], restored.tags
    assert_equal "decision", restored.category
    assert_equal ["alpha"], @memory.reload.tags, "and the root follows the new current version"
    assert_equal ["alpha"], @memory.version_tags
  end

  test "a purge makes the kept version the new first one" do
    @memory.create_version!(tags: ["beta"])
    @memory.create_version!(tags: ["gamma"])
    @memory.create_version!(tags: ["delta"])

    @memory.reload.purge_versions!(keep: 2)
    @memory.reload

    assert_equal ["gamma"], @memory.version_tags
    assert_equal ["delta"], @memory.tags
  end

  test "a purge down to one version leaves nothing held apart" do
    @memory.create_version!(tags: ["beta"])

    @memory.reload.purge_versions!(keep: 1)
    @memory.reload

    assert_nil @memory.first_version_tags
    assert_equal ["beta"], @memory.version_tags
  end

  test "an unversioned memory answers from its own columns" do
    assert_equal ["alpha"], @memory.version_tags
    assert_nil @memory.first_version_tags

    @memory.update_with_content(tags: ["edited"])

    assert_equal ["edited"], @memory.reload.version_tags
  end

  # --- tag normalization --------------------------------------------------------

  test "tags are trimmed before they are compared and saved" do
    memory = Memory.create_with_content(@workspace, title: "Tags", content: "x", tags: [" ops ", "ops", "a b", "  "])

    assert_equal ["ops", "a b"], memory.reload.tags
  end

  test "extra spaces around a tag are not a change" do
    assert_not @memory.differs_from?(tags: [" alpha "])
  end
end
