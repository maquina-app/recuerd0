json.workspace do
  json.id @workspace.id
  json.name @workspace.name
  json.url workspace_url(@workspace)
end

json.total_memories @total_memories
json.total_versions @total_versions
json.total_links @total_links
json.counts_by_category @counts_by_category
json.top_tags @top_tags
json.memories_by_week @memories_by_week
json.generated_at Time.current.utc
