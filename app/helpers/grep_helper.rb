module GrepHelper
  FTS5_OPERATORS = /\b(AND|OR|NOT)\b/
  COLUMN_PREFIX = /\w+:/
  GROUPING_CHARS = /[()"]/

  def grep_matches(memory, query, before: 0, after: 0)
    lines = memory.content&.body&.content.to_s.split("\n", -1)
    pattern = build_grep_pattern(query)
    return [] if pattern.nil?

    lines.each_with_index.filter_map do |line, idx|
      next unless line.match?(pattern)

      build_match(lines, idx, before: before, after: after)
    end
  end

  private

  def build_grep_pattern(query)
    terms = extract_search_terms(query)
    return if terms.empty?

    Regexp.union(terms.map { |t| Regexp.new(Regexp.escape(t), Regexp::IGNORECASE) })
  end

  def extract_search_terms(query)
    cleaned = query.gsub(FTS5_OPERATORS, " ")
    cleaned = cleaned.gsub(COLUMN_PREFIX, " ")
    cleaned = cleaned.gsub(GROUPING_CHARS, " ")

    cleaned.split.map(&:strip).reject(&:blank?).uniq
  end

  def build_match(lines, idx, before:, after:)
    range_start = [idx - before, 0].max
    range_end = [idx + after, lines.length - 1].min

    {
      line_number: idx + 1,
      line: lines[idx],
      context_before: (range_start < idx) ? lines[range_start...idx] : [],
      context_after: (idx < range_end) ? lines[(idx + 1)..range_end] : []
    }
  end
end
