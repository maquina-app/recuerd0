module GrepHelper
  FTS5_OPERATORS = /\b(AND|OR|NOT)\b/

  def grep_matches(memory, query, before: 0, after: 0)
    body = memory.content&.body.to_s
    lines = body.split("\n", -1)
    terms = extract_search_terms(query)
    return [] if terms.empty?

    pattern = Regexp.union(terms.map { |t| Regexp.new(Regexp.escape(t), Regexp::IGNORECASE) })

    matches = []
    lines.each_with_index do |line, idx|
      next unless line.match?(pattern)

      start_before = [idx - before, 0].max
      end_after = [idx + after, lines.length - 1].min

      matches << {
        line_number: idx + 1,
        line: line,
        context_before: (start_before < idx) ? lines[start_before...idx] : [],
        context_after: (idx < end_after) ? lines[(idx + 1)..end_after] : []
      }
    end
    matches
  end

  def extract_search_terms(query)
    # Strip FTS5 operators, column filters, and grouping
    cleaned = query.gsub(FTS5_OPERATORS, " ")
    cleaned = cleaned.gsub(/\w+:/, " ") # Remove column: prefixes
    cleaned = cleaned.gsub(/[()"]/, " ") # Remove grouping and quotes

    cleaned.split.map(&:strip).reject(&:blank?).uniq
  end
end
