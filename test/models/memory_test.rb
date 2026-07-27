require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  test "create_with_content creates memory and content" do
    memory = Memory.create_with_content(workspaces(:one), title: "Test", content: "Body text", tags: ["tag"])
    assert memory.persisted?
    assert_equal "Body text", memory.content.body.content
  end

  test "update_with_content updates title and body" do
    memory = memories(:one)
    memory.update_with_content(title: "Updated", content: "New body")
    memory.reload
    assert_equal "Updated", memory.title
    assert_equal "New body", memory.content.body.content
  end

  test "update_with_content preserves content when it is omitted" do
    body = "# Heading\n\n- first\n- second\n\n```ruby\nputs :exact\n```\n"
    memory = Memory.create_with_content(workspaces(:one), title: "Before", content: body, tags: ["old"])

    memory.update_with_content(tags: ["new"])

    assert_empty memory.errors
    assert_equal ["new"], memory.reload.tags
    assert_equal body, memory.content.body.content
  end

  test "update_with_content rejects blank overwrite and rolls back metadata" do
    memory = Memory.create_with_content(workspaces(:one), title: "Before", content: "Existing body")

    memory.update_with_content(title: "After", content: " \n")

    assert memory.errors.of_kind?(:content, :blank_overwrite)
    assert_equal "Before", memory.reload.title
    assert_equal "Existing body", memory.content.body.content
  end

  test "update_with_content accepts blank content when the body is already blank" do
    memory = Memory.create_with_content(workspaces(:one), title: "Before", content: "")

    memory.update_with_content(title: "After", content: "")

    assert_empty memory.errors
    assert_equal "After", memory.reload.title
    assert_equal "", memory.content.body.content
  end

  test "update_with_content accepts blank content when the content record is missing" do
    memory = workspaces(:one).memories.create!(title: "Before")

    memory.update_with_content(title: "After", content: "")

    assert_empty memory.errors
    assert_equal "After", memory.reload.title
    assert_equal "", memory.content.body.content
  end

  test "update_with_content still replaces content with a nonblank body" do
    memory = Memory.create_with_content(workspaces(:one), title: "Before", content: "Old body")

    memory.update_with_content(content: "# New body\n")

    assert_empty memory.errors
    assert_equal "# New body\n", memory.reload.content.body.content
  end

  test "create_version! creates child linked to parent" do
    parent = memories(:versioned_parent)
    version = parent.create_version!(content: "Version 2 content")
    assert version.persisted?
    assert_equal parent.id, version.parent_memory_id
  end

  test "create_version! syncs the root category to the new version's category" do
    memory = Memory.create_with_content(workspaces(:one), title: "Cat", content: "b", category: "general")
    memory.create_version!(category: "decision", content: "b2")
    assert_equal "decision", memory.reload.category,
      "root category should track the current version so filters and display agree"
  end

  test "create_version! leaves root category untouched when version inherits it" do
    memory = Memory.create_with_content(workspaces(:one), title: "Cat", content: "b", category: "preference")
    memory.create_version!(content: "b2")
    assert_equal "preference", memory.reload.category
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

  # Category tests

  test "defaults to general category when not specified" do
    memory = Memory.create_with_content(workspaces(:one), title: "Cat default", content: "body")
    assert_equal "general", memory.category
  end

  test "accepts all allowed categories" do
    Memory::CATEGORIES.each do |cat|
      memory = Memory.create_with_content(workspaces(:one), title: "Cat #{cat}", content: "body", category: cat)
      assert memory.persisted?, "Expected #{cat} to persist"
      assert_equal cat, memory.category
    end
  end

  test "rejects unknown category values" do
    memory = workspaces(:one).memories.build(title: "Bad", category: "nonsense", version: 1)
    assert_not memory.valid?
    assert_includes memory.errors[:category].first.to_s, "included"
  end

  test "by_category filters memories by category" do
    decision = Memory.create_with_content(workspaces(:one), title: "D", content: "b", category: "decision")
    discovery = Memory.create_with_content(workspaces(:one), title: "X", content: "b", category: "discovery")
    assert_includes Memory.by_category("decision"), decision
    assert_not_includes Memory.by_category("decision"), discovery
  end

  test "by_category is a no-op for blank input" do
    before = Memory.count
    assert_equal before, Memory.by_category(nil).count
    assert_equal before, Memory.by_category("").count
  end

  test "by_category is a no-op for invalid input" do
    assert_equal Memory.count, Memory.by_category("bogus").count
  end

  test "by_tag filters memories by an exact tag" do
    tagged = Memory.create_with_content(workspaces(:one), title: "T", content: "b", tags: ["onboarding", "billing"])
    other = Memory.create_with_content(workspaces(:one), title: "O", content: "b", tags: ["billing"])
    assert_includes Memory.by_tag("onboarding"), tagged
    assert_not_includes Memory.by_tag("onboarding"), other
  end

  test "by_tag is case-sensitive" do
    tagged = Memory.create_with_content(workspaces(:one), title: "T", content: "b", tags: ["Onboarding"])
    assert_not_includes Memory.by_tag("onboarding"), tagged
    assert_includes Memory.by_tag("Onboarding"), tagged
  end

  test "by_tag is a no-op for blank input" do
    before = Memory.count
    assert_equal before, Memory.by_tag(nil).count
    assert_equal before, Memory.by_tag("").count
  end

  test "create_version! syncs the root tags to the new version's tags" do
    memory = Memory.create_with_content(workspaces(:one), title: "T", content: "b", tags: ["old"])
    memory.create_version!(tags: ["new"], content: "b2")
    assert_equal ["new"], memory.reload.tags,
      "root tags should track the current version so the by_tag filter and display agree"
    assert_includes Memory.latest_versions.by_tag("new"), memory
  end

  test "create_version! moves the root to the top of updated ordering while syncing tags" do
    workspace = accounts(:one).workspaces.create!(name: "Version recency")
    workspace.memories.find_by!(title: WorkspaceStarter::TITLE).destroy!
    root = Memory.create_with_content(workspace, title: "Versioned", content: "v1", tags: ["old"])
    previously_newer = Memory.create_with_content(workspace, title: "Newer", content: "body")
    root.update_column(:updated_at, 2.days.ago)
    previously_newer.update_column(:updated_at, 1.day.ago)

    root.create_version!(content: "v2", tags: ["new"])

    ordered = workspace.memories.latest_versions.ordered_by("updated").to_a
    assert_equal root, ordered.first
    assert_equal ["new"], root.reload.tags
    assert_includes workspace.memories.latest_versions.by_tag("new"), root
  end

  test "update_with_content syncs the root tags" do
    memory = Memory.create_with_content(workspaces(:one), title: "T", content: "b", tags: ["old"])
    child = memory.create_version!(content: "b2")
    child.update_with_content(tags: ["fresh"])
    assert_equal ["fresh"], memory.reload.tags
    assert_includes Memory.latest_versions.by_tag("fresh"), memory
  end

  test "new version inherits category from parent when not specified" do
    parent = Memory.create_with_content(workspaces(:one), title: "Parent", content: "b", category: "decision")
    child = parent.create_version!(content: "v2")
    assert_equal "decision", child.category
  end

  test "new version can override category" do
    parent = Memory.create_with_content(workspaces(:one), title: "Parent", content: "b", category: "decision")
    child = parent.create_version!(content: "v2", category: "discovery")
    assert_equal "discovery", child.category
  end

  test "full_search removes entry on destroy" do
    memory = Memory.create_with_content(workspaces(:one), title: "Deletable", content: "body")
    assert_includes Memory.full_search("Deletable"), memory
    memory.destroy!
    assert_empty Memory.full_search("Deletable").to_a
  end

  # Workspace/MCP search

  test "search matches by title" do
    memory = Memory.create_with_content(workspaces(:one), title: "Kubernetes Migration", content: "body")
    assert_includes workspaces(:one).memories.search("Kubernetes"), memory
  end

  test "search matches by tag" do
    memory = Memory.create_with_content(workspaces(:one), title: "Tagged", content: "body", tags: ["infrastructure"])
    assert_includes workspaces(:one).memories.search("infrastructure"), memory
  end

  test "search matches by content body" do
    memory = Memory.create_with_content(workspaces(:one), title: "Notes", content: "the deployment pipeline runs nightly")
    assert_includes workspaces(:one).memories.search("deployment pipeline"), memory
  end

  test "search returns all for blank query" do
    all_count = Memory.count
    assert_equal all_count, Memory.search("").count
    assert_equal all_count, Memory.search(nil).count
  end

  test "search ranks FTS matches ahead of newer tag-only matches and deduplicates dual matches" do
    ws = accounts(:one).workspaces.create!(name: "Ranked Search")
    fts = Memory.create_with_content(ws, title: "Release notes", content: "body")
    dual = Memory.create_with_content(ws,
      title: "Release notes archive", content: "body", tags: ["release notes"])
    tag_only = Memory.create_with_content(ws,
      title: "Unrelated title", content: "body", tags: ["release notes"])
    tag_only.update_column(:updated_at, 1.hour.from_now)

    results = ws.memories.latest_versions.search("release notes").to_a

    assert_equal [fts.id, dual.id].sort, results.first(2).map(&:id).sort
    assert_equal tag_only, results.last
    assert_equal 1, results.count { |memory| memory == dual }
  end

  test "search rank is not replaced by updated_at recency" do
    ws = accounts(:one).workspaces.create!(name: "FTS Rank")
    stronger = Memory.create_with_content(ws,
      title: "Rank candidate",
      content: (["rankneedle"] * 20).join(" "))
    weaker = Memory.create_with_content(ws,
      title: "Newer rank candidate",
      content: "rankneedle")
    stronger.update_column(:updated_at, 2.days.ago)
    weaker.update_column(:updated_at, 1.hour.from_now)

    before_touch = ws.memories.search("rankneedle").pluck(:id)
    weaker.update_column(:updated_at, 2.hours.from_now)
    after_touch = ws.memories.search("rankneedle").pluck(:id)

    assert_equal stronger.id, before_touch.first
    assert_equal before_touch, after_touch
  end

  test "search orders tag-only matches by recency with an id tie-breaker" do
    ws = accounts(:one).workspaces.create!(name: "Tag Recency")
    older = Memory.create_with_content(ws, title: "Older", content: "body", tags: ["release notes"])
    first_tie = Memory.create_with_content(ws, title: "First tie", content: "body", tags: ["release notes"])
    second_tie = Memory.create_with_content(ws, title: "Second tie", content: "body", tags: ["release notes"])
    older.update_column(:updated_at, 2.days.ago)
    tied_at = 1.day.ago
    first_tie.update_column(:updated_at, tied_at)
    second_tie.update_column(:updated_at, tied_at)

    results = ws.memories.search("release notes").to_a

    assert_equal [second_tie, first_tie, older], results
  end

  test "search matches tags by case-insensitive whole-tag equality" do
    ws = accounts(:one).workspaces.create!(name: "Exact Tags")
    exact = Memory.create_with_content(ws, title: "Exact", content: "body", tags: ["Infrastructure"])
    partial = Memory.create_with_content(ws, title: "Partial", content: "body", tags: ["infrastructure-team"])

    results = ws.memories.search("infrastructure").to_a

    assert_includes results, exact
    assert_not_includes results, partial
    assert_empty ws.memories.search("infra").to_a
  end

  test "search treats tag wildcard characters literally" do
    ws = accounts(:one).workspaces.create!(name: "Literal Tags")
    literal = Memory.create_with_content(ws, title: "Literal", content: "body", tags: ["%"])
    plain = Memory.create_with_content(ws, title: "Plain", content: "body", tags: ["ordinary"])

    results = ws.memories.search("%").to_a

    assert_equal [literal], results
    assert_not_includes results, plain
  end

  test "search matches a multi-word tag exactly" do
    ws = accounts(:one).workspaces.create!(name: "Multiword Tags")
    exact = Memory.create_with_content(ws, title: "Exact", content: "body", tags: ["release notes"])
    partial = Memory.create_with_content(ws, title: "Partial", content: "body", tags: ["release notes draft"])

    results = ws.memories.search("release notes").to_a

    assert_includes results, exact
    assert_not_includes results, partial
  end

  test "one and two character searches use exact tags only" do
    ws = accounts(:one).workspaces.create!(name: "Short Tags")
    fts_only = Memory.create_with_content(ws, title: "Go language", content: "body")
    tag_match = Memory.create_with_content(ws, title: "Short tag", content: "body", tags: ["GO"])

    results = ws.memories.search("go").to_a

    assert_equal [tag_match], results
    assert_not_includes results, fts_only
  end

  test "search uses memory id to break equal FTS rank ties" do
    ws = accounts(:one).workspaces.create!(name: "FTS Ties")
    first = Memory.create_with_content(ws, title: "Tie needle", content: "identical")
    second = Memory.create_with_content(ws, title: "Tie needle", content: "identical")

    assert_equal [second, first], ws.memories.search("Tie needle").to_a
  end

  test "resolve_sort covers explicit, default, invalid, and relevance cases" do
    expected = {
      [nil, "query"] => "relevance",
      ["bogus", "query"] => "relevance",
      ["relevance", "query"] => "relevance",
      ["updated", "query"] => "updated",
      ["created", "query"] => "created",
      ["title", "query"] => "title",
      [nil, ""] => "updated",
      ["bogus", ""] => "updated",
      ["relevance", ""] => "updated",
      ["updated", ""] => "updated",
      ["created", ""] => "created",
      ["title", ""] => "title"
    }

    expected.each do |(sort, query), resolved|
      assert_equal resolved, Memory.resolve_sort(sort, query: query),
        "expected #{sort.inspect} with #{query.inspect} to resolve to #{resolved}"
    end
  end

  # ordered_by scope

  test "ordered_by title alphabetizes case-insensitively" do
    ws = accounts(:one).workspaces.create!(name: "Ordering A")
    ws.memories.find_by!(title: WorkspaceStarter::TITLE).destroy!
    Memory.create_with_content(ws, title: "banana", content: "b")
    Memory.create_with_content(ws, title: "Apple", content: "b")
    Memory.create_with_content(ws, title: "cherry", content: "b")
    titles = ws.memories.latest_versions.ordered_by("title").pluck(:title)
    assert_equal %w[Apple banana cherry], titles
  end

  test "ordered_by created sorts by created_at desc" do
    ws = accounts(:one).workspaces.create!(name: "Ordering B")
    ws.memories.find_by!(title: WorkspaceStarter::TITLE).destroy!
    first = Memory.create_with_content(ws, title: "First", content: "b")
    first.update_column(:created_at, 2.days.ago)
    second = Memory.create_with_content(ws, title: "Second", content: "b")
    second.update_column(:created_at, 1.day.ago)
    ordered = ws.memories.latest_versions.ordered_by("created").to_a
    assert_equal [second, first], ordered
  end

  test "ordered_by updated sorts by updated_at desc" do
    ws = accounts(:one).workspaces.create!(name: "Ordering C")
    ws.memories.find_by!(title: WorkspaceStarter::TITLE).destroy!
    older = Memory.create_with_content(ws, title: "Older", content: "b")
    newer = Memory.create_with_content(ws, title: "Newer", content: "b")
    older.update_column(:updated_at, 2.days.ago)
    newer.update_column(:updated_at, 1.minute.ago)
    ordered = ws.memories.latest_versions.ordered_by("updated").to_a
    assert_equal [newer, older], ordered
  end

  test "ordered_by relevance preserves the search relation order" do
    ws = accounts(:one).workspaces.create!(name: "Ordering Relevance")
    fts = Memory.create_with_content(ws, title: "Release notes", content: "body")
    tag = Memory.create_with_content(ws, title: "Other", content: "body", tags: ["release notes"])
    tag.update_column(:updated_at, 1.hour.from_now)

    ordered = ws.memories.search("release notes")
      .ordered_by(Memory.resolve_sort(nil, query: "release notes"))
      .to_a

    assert_equal [fts, tag], ordered
  end

  test "ordered_by rejects unresolved values" do
    assert_raises(ArgumentError) { Memory.ordered_by(nil).load }
    assert_raises(ArgumentError) { Memory.ordered_by("bogus").load }
  end
end
