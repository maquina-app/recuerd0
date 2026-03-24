json.query @query
json.total_results @pagy.count

json.results @memories do |memory|
  json.partial! "memories/memory", memory: memory

  if @grep_mode
    lines = memory.content&.body.to_s.split("\n", -1)
    json.total_lines lines.length
    json.matches grep_matches(memory, @query, before: @before_lines, after: @after_lines)
  else
    json.snippet memory_snippet(memory)
  end
end
