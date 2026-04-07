json.workspace do
  json.call(@workspace, :id, :name, :description, :memories_count)
  json.state @workspace.archived? ? "archived" : "active"
  json.updated_at @workspace.updated_at.utc
  json.url workspace_url(@workspace)
end

json.pinned_memories(@pinned_memories) do |memory|
  json.call(memory, :id, :title, :source, :tags)
  json.pinned_at memory.pins.find { |p| p.user_id == Current.user.id }&.created_at&.utc
  json.updated_at memory.updated_at.utc
  json.url workspace_memory_url(@workspace, memory)

  if @include_body
    body = memory.content&.body.to_s
    json.body body.truncate(@max_body_chars, omission: "…")
    json.body_truncated body.length > @max_body_chars
  end
end

json.stats do
  json.total_memories @workspace.memories_count
  json.total_pinned @total_pinned
  json.returned_pinned @pinned_memories.size
end

json.generated_at Time.current.utc
