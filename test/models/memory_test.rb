require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  test "create_with_content creates memory and content" do
    memory = Memory.create_with_content(workspaces(:one), title: "Test", content: "Body text", tags: ["tag"])
    assert memory.persisted?
    assert_equal "Body text", memory.content.body
  end

  test "update_with_content updates title and body" do
    memory = memories(:one)
    memory.update_with_content(title: "Updated", content: "New body")
    memory.reload
    assert_equal "Updated", memory.title
    assert_equal "New body", memory.content.body
  end

  test "create_version! creates child linked to parent" do
    parent = memories(:versioned_parent)
    version = parent.create_version!(content: "Version 2 content")
    assert version.persisted?
    assert_equal parent.id, version.parent_memory_id
  end

  test "consolidate_versions! collapses to single version" do
    parent = memories(:versioned_parent)
    parent.create_version!(content: "v2")
    assert parent.all_versions.count > 1
    parent.consolidate_versions!
    assert_equal 1, parent.all_versions.count
  end

  test "display_title returns title when present" do
    assert_equal "Meeting Notes", memories(:one).display_title
  end

  test "display_title returns fallback when blank" do
    memory = Memory.new(title: "")
    assert_equal I18n.t("models.memory.untitled"), memory.display_title
  end

  test "sets version automatically on create" do
    memory = Memory.create_with_content(workspaces(:one), title: "New", content: "content")
    assert_equal 1, memory.version
  end
end
