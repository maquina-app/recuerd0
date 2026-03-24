json.partial! "memories/memory", memory: memory

json.content do
  body = memory.content&.body.to_s
  lines = body.split("\n", -1)
  total = lines.length

  if @line_start || @line_end
    start_idx = [(@line_start || 1) - 1, 0].max
    end_idx = [(@line_end || total) - 1, total - 1].min
    json.body lines[start_idx..end_idx].join("\n")
    json.line_start start_idx + 1
    json.line_end end_idx + 1
  else
    json.body memory.content&.body
    json.line_start 1
    json.line_end total
  end
  json.total_lines total
end
