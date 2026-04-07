json.array!(@links) do |memory|
  json.id memory.id
  json.title memory.title
  json.category memory.category
  json.tags memory.tags
  json.source memory.source
  json.updated_at memory.updated_at.utc
  json.url workspace_memory_url(memory.workspace, memory)
  json.workspace do
    json.id memory.workspace.id
    json.name memory.workspace.name
    json.url workspace_url(memory.workspace)
  end
end
