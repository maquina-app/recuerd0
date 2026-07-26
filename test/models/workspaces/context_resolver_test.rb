require "test_helper"

class Workspaces::ContextResolverTest < ActiveSupport::TestCase
  setup do
    @account = Account.create!(name: "Context resolver")
    @user = @account.users.create!(
      email_address: "resolver@example.com",
      password: "password",
      role: "admin"
    )
    @workspace = @account.workspaces.create!(name: "Resolver workspace")
  end

  test "returns category-matching pins in the existing per-user order and counts before limiting" do
    first = create_memory(title: "First", category: "decision")
    second = create_memory(title: "Second", category: "decision")
    ignored = create_memory(title: "Ignored", category: "general")
    first.pin!(@user)
    second.pin!(@user)
    ignored.pin!(@user)

    first.pin_for(@user).update_column(:created_at, 2.minutes.ago)
    second.pin_for(@user).update_column(:created_at, 1.minute.ago)

    result = resolve(limit: 1, category: "decision")

    assert_equal "pins", result[:source]
    assert_equal 2, result[:total_pinned]
    assert_equal [second.id], result[:memories].map(&:id)
  end

  test "applies category before choosing pins or recent fallback" do
    pinned = create_memory(title: "Pinned general", category: "general")
    recent = create_memory(title: "Recent decision", category: "decision")
    pinned.pin!(@user)

    result = resolve(category: "decision")

    assert_equal "recent", result[:source]
    assert_equal 0, result[:total_pinned]
    assert_equal [recent.id], result[:memories].map(&:id)
  end

  test "without a user returns latest root versions by updated time" do
    older = create_memory(title: "Older")
    newer = create_memory(title: "Newer")
    child = older.create_version!(title: "Older current", content: "v2")
    older.update_column(:updated_at, 2.days.ago)
    newer.update_column(:updated_at, 1.day.ago)

    result = resolve(user: nil, limit: 2)

    assert_equal "recent", result[:source]
    assert_equal 0, result[:total_pinned]
    assert_equal [newer.id, older.id], result[:memories].map(&:id)
    assert_not_includes result[:memories].map(&:id), child.id
    assert result[:memories].all?(&:root_version?)
  end

  test "versioning a memory moves its root to the front of recent context" do
    versioned = create_memory(title: "Versioned")
    other = create_memory(title: "Other")
    versioned.update_column(:updated_at, 2.days.ago)
    other.update_column(:updated_at, 1.day.ago)

    travel_to Time.current do
      versioned.create_version!(title: "Versioned current", content: "v2")
    end

    result = resolve(user: nil, limit: 2)

    assert_equal [versioned.id, other.id], result[:memories].map(&:id)
  end

  test "a pin on a child version surfaces the root memory" do
    root = create_memory(title: "Root")
    child = root.create_version!(title: "Child", content: "v2")
    child.pin!(@user)

    result = resolve

    assert_equal "pins", result[:source]
    assert_equal 1, result[:total_pinned]
    assert_equal [root.id], result[:memories].map(&:id)
  end

  test "pins and recent branches preload child version content for resolution" do
    pinned = create_memory(title: "Pinned")
    pinned_child = pinned.create_version!(title: "Pinned current", content: "pinned v2")
    pinned.pin!(@user)

    pinned_result = resolve
    assert_resolution_preloaded(pinned_result[:memories].first, pinned_child)

    pinned.unpin!(@user)
    recent = create_memory(title: "Recent")
    recent_child = recent.create_version!(title: "Recent current", content: "recent v2")

    recent_result = resolve
    recent_root = recent_result[:memories].find { |memory| memory.id == recent.id }
    assert_resolution_preloaded(recent_root, recent_child)
  end

  test "an empty workspace returns an empty recent result" do
    result = resolve

    assert_equal({memories: [], source: "recent", total_pinned: 0}, result)
  end

  private

  def create_memory(title:, category: "general")
    Memory.create_with_content(
      @workspace,
      title: title,
      category: category,
      content: "#{title} body"
    )
  end

  def resolve(user: @user, limit: 10, category: nil)
    Workspaces::ContextResolver.call(
      workspace: @workspace,
      user: user,
      limit: limit,
      category: category
    )
  end

  def assert_resolution_preloaded(root, expected_current)
    assert root.association(:content).loaded?
    assert root.association(:pins).loaded?
    assert root.association(:workspace).loaded?
    assert root.association(:child_versions).loaded?
    assert root.child_versions.all? { |child| child.association(:content).loaded? }
    assert_equal expected_current, root.resolve_current_version
    assert_equal expected_current.content.body.content,
      root.resolve_current_version.content.body.content
  end
end
