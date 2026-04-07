require "test_helper"

class MemoryLinkTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @workspace_a = workspaces(:one)
    @workspace_b = Workspace.create!(name: "Other WS", account: @account)
    @memory_a = memories(:one)
    @memory_b = @workspace_b.memories.create!(title: "B")
    @memory_b.create_content!(body: "b")
  end

  test "normalizes order so smaller id is from_memory_id" do
    bigger, smaller = [@memory_a, @memory_b].max_by(&:id), [@memory_a, @memory_b].min_by(&:id)
    link = MemoryLink.create!(from_memory: bigger, to_memory: smaller)
    assert_equal smaller.id, link.from_memory_id
    assert_equal bigger.id, link.to_memory_id
  end

  test "rejects self-link" do
    link = MemoryLink.new(from_memory: @memory_a, to_memory: @memory_a)
    assert_not link.valid?
    assert_match(/itself/, link.errors.full_messages.join)
  end

  test "rejects cross-account link" do
    other_account_workspace = workspaces(:two)
    other_memory = memories(:two)
    assert_not_equal @account.id, other_account_workspace.account_id

    link = MemoryLink.new(from_memory: @memory_a, to_memory: other_memory)
    assert_not link.valid?
    assert_match(/same account/, link.errors.full_messages.join)
  end

  test "uniqueness in either direction" do
    MemoryLink.create!(from_memory: @memory_a, to_memory: @memory_b)
    dup = MemoryLink.new(from_memory: @memory_b, to_memory: @memory_a)
    assert_not dup.valid?
  end

  test "involving scope returns links in both directions" do
    link = MemoryLink.create!(from_memory: @memory_a, to_memory: @memory_b)
    assert_includes MemoryLink.involving(@memory_a), link
    assert_includes MemoryLink.involving(@memory_b), link
  end

  test "Memory#linked_memories returns union" do
    MemoryLink.create!(from_memory: @memory_a, to_memory: @memory_b)
    assert_includes @memory_a.linked_memories, @memory_b
    assert_includes @memory_b.linked_memories, @memory_a
  end

  test "deleting a memory destroys its links" do
    MemoryLink.create!(from_memory: @memory_a, to_memory: @memory_b)
    assert_difference("MemoryLink.count", -1) do
      @memory_b.destroy
    end
  end

  test "Memory#links_count returns total" do
    @memory_c = @workspace_a.memories.create!(title: "C")
    @memory_c.create_content!(body: "c")
    MemoryLink.create!(from_memory: @memory_a, to_memory: @memory_b)
    MemoryLink.create!(from_memory: @memory_a, to_memory: @memory_c)
    assert_equal 2, @memory_a.reload.links_count
  end
end
