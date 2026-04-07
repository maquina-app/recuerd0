json.id @other.id
json.title @other.title
json.category @other.category
json.tags @other.tags
json.source @other.source
json.updated_at @other.updated_at.utc
json.url workspace_memory_url(@other.workspace, @other)
json.workspace do
  json.id @other.workspace.id
  json.name @other.workspace.name
  json.url workspace_url(@other.workspace)
end
