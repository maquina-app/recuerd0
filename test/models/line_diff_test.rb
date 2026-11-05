require "test_helper"

class LineDiffTest < ActiveSupport::TestCase
  test "reports added and removed lines with context and collapsed gaps" do
    old_text = (1..10).map { |n| "line #{n}" }.join("\n")
    new_text = old_text.sub("line 5", "line five").concat("\nline 11")

    diff = LineDiff.new(old_text, new_text)

    assert diff.changed?
    assert_equal 2, diff.added_count
    assert_equal 1, diff.removed_count
    kinds = diff.lines.map(&:kind)
    assert_includes kinds, :gap
    assert_equal "line 5", diff.lines.find { |line| line.kind == :removed }.text
    assert_equal ["line five", "line 11"], diff.lines.select { |line| line.kind == :added }.map(&:text)
    assert_includes diff.lines.map(&:text), "line 4"
    assert_not_includes diff.lines.map(&:text), "line 1"
  end

  test "identical text has no changes" do
    assert_not LineDiff.new("same\ntext", "same\ntext").changed?
  end

  test "handles a missing side" do
    assert_equal 2, LineDiff.new(nil, "a\nb").added_count
    assert_equal 1, LineDiff.new("a", nil).removed_count
  end

  test "very large rewrites fall back to removed then added without building the table" do
    old_text = (1..1000).map { |n| "old #{n}" }.join("\n")
    new_text = (1..1000).map { |n| "new #{n}" }.join("\n")

    diff = LineDiff.new(old_text, new_text)

    assert_equal 1000, diff.added_count
    assert_equal 1000, diff.removed_count
  end
end
