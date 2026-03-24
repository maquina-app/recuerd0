require "test_helper"
require "ostruct"

class GrepHelperTest < ActionView::TestCase
  include GrepHelper

  # --- extract_search_terms ---

  test "extract_search_terms with simple single term" do
    assert_equal ["hello"], extract_search_terms("hello")
  end

  test "extract_search_terms with multiple terms" do
    assert_equal ["hello", "world"], extract_search_terms("hello world")
  end

  test "extract_search_terms strips AND OR NOT operators" do
    assert_equal ["hello", "world"], extract_search_terms("hello AND world")
    assert_equal ["hello", "world"], extract_search_terms("hello OR world")
    assert_equal ["hello", "world"], extract_search_terms("NOT hello AND world")
  end

  test "extract_search_terms strips column prefixes" do
    assert_equal ["hello"], extract_search_terms("title:hello")
    assert_equal ["world"], extract_search_terms("body:world")
  end

  test "extract_search_terms strips quotes and parentheses" do
    assert_equal ["hello", "world"], extract_search_terms('"hello world"')
    assert_equal ["hello", "world"], extract_search_terms("(hello OR world)")
  end

  test "extract_search_terms with complex FTS5 query" do
    query = '(title:hello OR body:"world test") AND NOT goodbye'
    result = extract_search_terms(query)
    assert_equal ["hello", "world", "test", "goodbye"], result
  end

  test "extract_search_terms returns empty array for operator-only query" do
    assert_equal [], extract_search_terms("AND OR NOT")
  end

  # --- grep_matches ---

  def build_memory(body)
    OpenStruct.new(content: OpenStruct.new(body: body))
  end

  test "grep_matches finds matching line with correct line_number" do
    memory = build_memory("apple\nbanana\ncherry")
    results = grep_matches(memory, "banana")

    assert_equal 1, results.length
    assert_equal 2, results.first[:line_number]
    assert_equal "banana", results.first[:line]
  end

  test "grep_matches returns empty array for no matches" do
    memory = build_memory("apple\nbanana\ncherry")
    results = grep_matches(memory, "dragonfruit")

    assert_empty results
  end

  test "grep_matches returns context_before lines" do
    memory = build_memory("line1\nline2\nline3\nline4\nline5")
    results = grep_matches(memory, "line4", before: 2)

    assert_equal 1, results.length
    assert_equal ["line2", "line3"], results.first[:context_before]
  end

  test "grep_matches returns context_after lines" do
    memory = build_memory("line1\nline2\nline3\nline4\nline5")
    results = grep_matches(memory, "line2", after: 2)

    assert_equal 1, results.length
    assert_equal ["line3", "line4"], results.first[:context_after]
  end

  test "grep_matches returns both context_before and context_after" do
    memory = build_memory("line1\nline2\nline3\nline4\nline5")
    results = grep_matches(memory, "line3", before: 1, after: 1)

    assert_equal 1, results.length
    assert_equal ["line2"], results.first[:context_before]
    assert_equal ["line4"], results.first[:context_after]
  end

  test "grep_matches clamps context to beginning of content" do
    memory = build_memory("line1\nline2\nline3")
    results = grep_matches(memory, "line1", before: 5)

    assert_equal 1, results.length
    assert_empty results.first[:context_before]
  end

  test "grep_matches clamps context to end of content" do
    memory = build_memory("line1\nline2\nline3")
    results = grep_matches(memory, "line3", after: 5)

    assert_equal 1, results.length
    assert_empty results.first[:context_after]
  end

  test "grep_matches is case-insensitive" do
    memory = build_memory("Hello World\ngoodbye")
    results = grep_matches(memory, "hello")

    assert_equal 1, results.length
    assert_equal "Hello World", results.first[:line]
  end

  test "grep_matches finds multiple matches in same content" do
    memory = build_memory("apple pie\nbanana split\napple sauce")
    results = grep_matches(memory, "apple")

    assert_equal 2, results.length
    assert_equal 1, results.first[:line_number]
    assert_equal 3, results.last[:line_number]
  end

  test "grep_matches with nil content returns empty array" do
    memory = OpenStruct.new(content: nil)
    results = grep_matches(memory, "anything")

    assert_empty results
  end
end
