json.partial! "memories/memory", memory: memory

body = memory.content&.body&.content.to_s
lines = body.split("\n", -1)
total_lines = lines.length

if @grep_mode
  json.content do
    json.total_lines total_lines
    json.matches grep_matches(memory, @grep_query, before: @before_lines, after: @after_lines)
  end
elsif @line_start || @line_end
  start_idx = [(@line_start || 1) - 1, 0].max
  end_idx = [(@line_end || total_lines) - 1, total_lines - 1].min

  json.content do
    json.body lines[start_idx..end_idx].join("\n")
    json.line_start start_idx + 1
    json.line_end end_idx + 1
    json.total_lines total_lines
  end
else
  json.cache! [memory, :content] do
    json.content do
      json.body body
      json.line_start 1
      json.line_end total_lines
      json.total_lines total_lines
    end
  end
end
