json.partial! "memories/memory", memory: memory

json.content do
  body = memory.content&.body.to_s
  lines = body.split("\n", -1)
  total = lines.length

  if @grep_mode
    json.total_lines total
    json.matches grep_matches(memory, @grep_query, before: @before_lines, after: @after_lines)
  else
    start_idx = [(@line_start || 1) - 1, 0].max
    end_idx = [(@line_end || total) - 1, total - 1].min

    json.body lines[start_idx..end_idx].join("\n")
    json.line_start start_idx + 1
    json.line_end end_idx + 1
    json.total_lines total
  end
end
