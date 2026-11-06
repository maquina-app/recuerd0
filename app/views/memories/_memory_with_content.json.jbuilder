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
  # A window can legitimately land past the end, because a memory can shrink between
  # two reads. It then comes back empty, wherever it starts. Slicing by length keeps a
  # negative end from counting back from the last line.
  start_idx = ((@line_start || 1) - 1).clamp(0, total_lines)
  end_idx = ((@line_end || total_lines) - 1).clamp(start_idx - 1, total_lines - 1)

  json.content do
    json.body lines.slice(start_idx, end_idx - start_idx + 1).join("\n")
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
