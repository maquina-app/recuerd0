json.format "recuerd0.workspace_export"
json.format_version 1
json.exported_at @exported_at

json.workspace do
  json.call(@workspace, :id, :name, :description, :memories_count)
  json.archived @workspace.archived?
  json.created_at @workspace.created_at.utc
  json.updated_at @workspace.updated_at.utc
end

json.memories @root_memories do |memory|
  json.partial! "memories/memory", memory: memory
  json.content memory.content&.body&.content.to_s

  json.versions @versions_by_root_id.fetch(memory.id).sort_by(&:version) do |version|
    json.partial! "memories/memory", memory: version
    json.content version.content&.body&.content.to_s
  end
end
