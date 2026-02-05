json.cache! memory do
  json.call(memory, :id, :title, :tags, :source, :version)
  json.version_label memory.version_label
  json.has_versions memory.has_versions?
  json.created_at memory.created_at.utc
  json.updated_at memory.updated_at.utc
  json.url workspace_memory_url(memory.workspace, memory)

  json.workspace do
    json.id memory.workspace.id
    json.name memory.workspace.name
    json.url workspace_url(memory.workspace)
  end
end
