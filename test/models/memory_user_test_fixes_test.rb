require "test_helper"

class MemoryUserTestFixesTest < ActiveSupport::TestCase
  setup do
    @workspace = workspaces(:one)
  end

  # U-03
  test "a fence right after a list gets its blank line on save" do
    memory = Memory.create_with_content(@workspace, title: "Fence", content: "- one\n- two\n```ruby\nputs 1\n```")

    assert_equal "- one\n- two\n\n```ruby\nputs 1\n```", memory.content.body.content
    assert_includes memory.content.body.to_html, %(<pre class="highlight ruby">)
    assert_no_match(%r{<code>ruby}, memory.content.body.to_html)
  end

  test "the same holds for a new version and an in-place update" do
    memory = Memory.create_with_content(@workspace, title: "Fence", content: "x")

    version = memory.create_version!(content: "1. one\n```\ncode\n```")
    assert_equal "1. one\n\n```\ncode\n```", version.content.body.content

    version.update_with_content(content: "- a\n~~~\ncode\n~~~")
    assert_equal "- a\n\n~~~\ncode\n~~~", version.content.body.content
  end

  test "content saved before the fix renders correctly anyway" do
    markdown = ActionText::Markdown.new(content: "- one\n- two\n```ruby\nputs 1\n```")

    assert_includes markdown.to_html, %(<pre class="highlight ruby">)
  end

  test "separating fences leaves everything else byte for byte" do
    [
      "plain text",
      "- one\n\n```ruby\nputs 1\n```",
      "text\n```\n- not a list\n```\nafter",
      "```\n- inside\n```\n- after\n",
      "- one\n  ```ruby\n  indented stays with its item\n  ```\n- two",
      "- one\n\ntext\n```\nx\n```",
      ""
    ].each do |markdown|
      assert_equal markdown, ActionText::Markdown.separate_fences_from_lists(markdown)
    end
  end

  test "separating fences is idempotent" do
    once = ActionText::Markdown.separate_fences_from_lists("- one\n```\nx\n```")

    assert_equal once, ActionText::Markdown.separate_fences_from_lists(once)
  end

  # U-05
  test "memories_count counts memories, not versions" do
    workspace = accounts(:one).workspaces.create!(name: "Counting", start_with_map: "0")
    assert_equal 0, workspace.memories_count

    memory = Memory.create_with_content(workspace, title: "A", content: "x")
    2.times { |n| memory.create_version!(content: "v#{n}") }
    Memory.create_with_content(workspace, title: "B", content: "x")

    assert_equal 2, workspace.reload.memories_count

    memory.purge_versions!(keep: 1)
    assert_equal 2, workspace.reload.memories_count

    memory.reload.destroy
    assert_equal 1, workspace.reload.memories_count
  end

  # U-13
  test "a memory needs a title or some content, through the one door they all share" do
    [{title: "", content: ""}, {title: "  ", content: " \n "}, {}].each do |attributes|
      assert_no_difference("Memory.count") do
        memory = Memory.create_with_content(@workspace, attributes)
        assert memory.errors[:base].any?
        assert_not memory.persisted?
      end
    end

    assert Memory.create_with_content(@workspace, title: "Just a title").persisted?
    assert Memory.create_with_content(@workspace, content: "Just content").persisted?
  end

  # U-37
  test "a preview drops a leading heading that repeats the title" do
    memory = Memory.create_with_content(@workspace, title: "Deploy notes", content: "## Deploy notes\n\nWe use Kamal.")
    assert_equal "We use Kamal.", memory.content.preview_text(title: memory.title)

    other = Memory.create_with_content(@workspace, title: "Something else", content: "## Deploy notes\n\nWe use Kamal.")
    assert_equal "Deploy notes\n\nWe use Kamal.", other.content.preview_text(title: other.title)
  end

  # U-20 and friends live with their controllers; the token mechanics live here.
  test "revoking invitations invalidates links minted before, and only those" do
    account = accounts(:one)
    old_token = account.generate_invitation_token
    assert_equal account, Account.find_by_invitation_token(old_token)

    account.revoke_invitations!

    assert_nil Account.find_by_invitation_token(old_token)
    assert_equal account, Account.find_by_invitation_token(account.generate_invitation_token)
  end

  test "a link signed before generations existed still works until revoked" do
    account = accounts(:one)
    legacy = Rails.application.message_verifier(:account_invitations).generate(account.id, expires_in: 7.days)
    assert_equal account, Account.find_by_invitation_token(legacy)

    account.revoke_invitations!
    assert_nil Account.find_by_invitation_token(legacy)
  end

  # U-43
  test "a workspace name is trimmed" do
    workspace = accounts(:one).workspaces.build(name: "   ")

    assert_not workspace.valid?
    assert_equal "", workspace.name
  end

  # U-19
  test "a workspace skips its map only when asked" do
    assert_no_difference("Memory.count") do
      accounts(:one).workspaces.create!(name: "Blank", start_with_map: "0")
    end
    assert_difference("Memory.count", 1) do
      accounts(:one).workspaces.create!(name: "Mapped", start_with_map: "1")
    end
    assert_difference("Memory.count", 1) do
      accounts(:one).workspaces.create!(name: "Default")
    end
  end
end
