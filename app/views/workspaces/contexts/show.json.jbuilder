json.workspace do
  json.call(@workspace, :id, :name, :description, :memories_count)
  json.state @workspace.archived? ? "archived" : "active"
  json.updated_at @workspace.updated_at.utc
  json.url workspace_url(@workspace)
end

context_memories = @memories.map do |memory|
  current = memory.resolve_current_version
  payload = {
    id: memory.id,
    title: current.title,
    source: current.source,
    tags: current.tags,
    category: current.category,
    links_count: memory.links_count,
    pinned_at: memory.pins.find { |pin| pin.user_id == Current.user.id }&.created_at&.utc,
    updated_at: current.updated_at.utc,
    url: workspace_memory_url(@workspace, memory)
  }

  if @include_body
    body = current.content&.body&.content.to_s
    payload[:body] = body.truncate(@max_body_chars, omission: "…")
    payload[:body_truncated] = body.length > @max_body_chars
  end

  payload
end

json.memories context_memories
json.pinned_memories context_memories
json.context_source @context_source

json.stats do
  json.total_memories @workspace.memories_count
  json.total_pinned @total_pinned
  json.returned @memories.size
  json.returned_pinned @memories.size
end

json.generated_at Time.current.utc
