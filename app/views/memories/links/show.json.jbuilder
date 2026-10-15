json.id @other.id
json.title @other.title
json.category @other.category
json.tags @other.tags
json.source @other.source
json.obsolete @other.obsolete?
json.current @other.current_version?
json.root_id @other.root_memory.id
json.updated_at @other.updated_at.utc
json.url workspace_memory_url(@other.workspace, @other)
json.workspace do
  json.id @other.workspace.id
  json.name @other.workspace.name
  json.state @other.workspace.status
  json.url workspace_url(@other.workspace)
end
