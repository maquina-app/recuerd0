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

  # root_version? tests

  test "root_version? returns true when parent_memory_id is nil" do
    assert memories(:versioned_parent).root_version?
  end

  test "root_version? returns false for child versions" do
    parent = memories(:versioned_parent)
    child = parent.create_version!(content: "child content")
    assert_not child.root_version?
  end

  # current_version tests

  test "current_version returns self for root with no children" do
    memory = memories(:one)
    assert_equal memory, memory.current_version
  end

  test "current_version returns highest-version child for root with children" do
    parent = memories(:versioned_parent)
    parent.create_version!(content: "v2")
    v3 = parent.create_version!(content: "v3")
    assert_equal v3, parent.current_version
  end

  test "current_version called on child delegates through root" do
    parent = memories(:versioned_parent)
    v2 = parent.create_version!(content: "v2")
    v3 = parent.create_version!(content: "v3")
    assert_equal v3, v2.current_version
  end

  test "current_version? returns true for the latest child version" do
    parent = memories(:versioned_parent)
    parent.create_version!(content: "v2")
    v3 = parent.create_version!(content: "v3")
    assert v3.current_version?
  end

  test "current_version? returns false for root when children exist" do
    parent = memories(:versioned_parent)
    parent.create_version!(content: "v2")
    assert_not parent.current_version?
  end

  test "current_version? returns true for root with no children" do
    memory = memories(:one)
    assert memory.current_version?
  end

  # Full-text search tests

  test "full_search finds memory by title" do
    memory = Memory.create_with_content(workspaces(:one), title: "Architecture Overview", content: "body")
    assert_includes Memory.full_search("Architect"), memory
  end

  test "full_search finds memory by content body" do
    memory = Memory.create_with_content(workspaces(:one), title: "Notes", content: "kubernetes cluster running")
    assert_includes Memory.full_search("kubernetes"), memory
  end

  test "full_search returns none for blank or short query" do
    assert_empty Memory.full_search("").to_a
    assert_empty Memory.full_search(nil).to_a
    assert_empty Memory.full_search("ab").to_a
  end

  test "full_search indexes newest version content" do
    parent = Memory.create_with_content(workspaces(:one), title: "OriginalTitle", content: "original body")
    assert_includes Memory.full_search("OriginalTitle"), parent

    parent.create_version!(title: "NewestTitle", content: "newest body")
    assert_includes Memory.full_search("NewestTitle"), parent
    assert_empty Memory.full_search("OriginalTitle").to_a
  end

  test "full_search scoped to workspace" do
    m1 = Memory.create_with_content(workspaces(:one), title: "SharedTerm", content: "body")
    m2 = Memory.create_with_content(workspaces(:two), title: "SharedTerm", content: "body")
    results = workspaces(:one).memories.full_search("SharedTerm")
    assert_includes results, m1
    assert_not_includes results, m2
  end

  test "full_search updates index when content changes" do
    memory = Memory.create_with_content(workspaces(:one), title: "Title", content: "original text here")
    assert_includes Memory.full_search("original"), memory
    memory.update_with_content(title: "Title", content: "changed text here")
    assert_not_includes Memory.full_search("original"), memory
    assert_includes Memory.full_search("changed"), memory
  end

  test "full_search removes entry on destroy" do
    memory = Memory.create_with_content(workspaces(:one), title: "Deletable", content: "body")
    assert_includes Memory.full_search("Deletable"), memory
    memory.destroy!
    assert_empty Memory.full_search("Deletable").to_a
  end
end
