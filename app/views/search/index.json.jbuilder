json.query @query
json.total_results @pagy.count
json.related_results @related.size
json.obsolete_hidden @obsolete_hidden_count.to_i
json.inactive_hidden @inactive_hidden_count.to_i

# Keyword hits first, then the semantic fallback (page one only). `match` tells
# a result that contains the query words from one that is only close in meaning.
keyword = @memories.map { |memory| [memory, nil] }
related = @related.map { |match| [match.memory.resolve_current_version, match.similarity] }

json.results keyword + related do |(memory, similarity)|
  json.partial! "memories/memory", memory: memory
  json.match similarity ? "related" : "keyword"
  json.similarity similarity if similarity

  if @grep_mode && similarity.nil?
    lines = memory.content&.body&.content.to_s.split("\n", -1)
    json.total_lines lines.length
    json.matches grep_matches(memory, @query, before: @before_lines, after: @after_lines)
  else
    json.snippet memory_snippet(memory)
  end
end
