json.array!(@links) do |memory|
  json.id memory.id
  json.title memory.title
  json.category memory.category
  json.tags memory.tags
  json.source memory.source
  json.obsolete memory.obsolete?
  json.current memory.current_version?
  json.root_id memory.root_memory.id
  json.updated_at memory.updated_at.utc
  json.url workspace_memory_url(memory.workspace, memory)
  json.workspace do
    json.id memory.workspace.id
    json.name memory.workspace.name
    json.state memory.workspace.status
    json.url workspace_url(memory.workspace)
  end
end
