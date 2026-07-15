json.workspace do
  json.id @workspace.id
  json.name @workspace.name
  json.url workspace_url(@workspace)
end

json.candidates @clusters do |cluster|
  json.score cluster.score
  json.reasons cluster.reasons
  json.memories cluster.memories do |memory|
    current = memory.resolve_current_version
    json.id memory.id # stable root id, matching read/update/link IDs
    json.title current.title
    json.category current.category
    json.tags current.tags
    json.source current.source
    json.version current.version
    json.updated_at current.updated_at.utc
    json.url workspace_memory_url(memory.workspace, memory)
  end
end

json.generated_at Time.current.utc
