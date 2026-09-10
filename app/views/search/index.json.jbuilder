json.query @query
json.total_results @pagy.count
json.obsolete_hidden @obsolete_hidden_count.to_i

json.results @memories do |memory|
  json.partial! "memories/memory", memory: memory

  if @grep_mode
    lines = memory.content&.body&.content.to_s.split("\n", -1)
    json.total_lines lines.length
    json.matches grep_matches(memory, @query, before: @before_lines, after: @after_lines)
  else
    json.snippet memory_snippet(memory)
  end
end
