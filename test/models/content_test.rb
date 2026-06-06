require "test_helper"

class ContentTest < ActiveSupport::TestCase
  test "belongs to memory" do
    assert_equal memories(:one), contents(:one).memory
  end

  test "body is an ActionText::Markdown holding the raw markdown" do
    content = contents(:one)
    assert_instance_of ActionText::Markdown, content.body
    assert_equal "# Meeting Notes\n\nDiscussed project timeline.", content.body.content
  end

  test "body= accepts a String and persists it" do
    content = contents(:one)
    content.update!(body: "new raw **markdown**")
    assert_equal "new raw **markdown**", content.reload.body.content
  end

  test "plain_text strips markdown from the raw body" do
    assert_equal "Meeting Notes\n\nDiscussed project timeline.", contents(:one).plain_text
  end

  test "touch propagates to parent memory" do
    memory = memories(:one)
    content = contents(:one)
    original_updated_at = memory.updated_at

    travel_to 1.minute.from_now do
      content.touch
      assert_operator memory.reload.updated_at, :>, original_updated_at
    end
  end

  test "updating body reindexes parent memory for search" do
    memory = Memory.create_with_content(workspaces(:one), title: "Test", content: "initial text")
    assert_includes Memory.full_search("initial"), memory
    memory.content.update!(body: "replaced text")
    assert_not_includes Memory.full_search("initial"), memory
    assert_includes Memory.full_search("replaced"), memory
  end
end
