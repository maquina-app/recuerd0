# A link attaches to the root, so id stays the root's, which is what removing a link
# takes. Everything it reports is the current version's, because a root keeps v1's title
# and source.
current = memory.current_version

json.id memory.id
json.title current.title
json.category current.version_category
json.tags current.version_tags
json.source current.source
json.obsolete current.obsolete?
json.current true
json.root_id memory.id
json.updated_at current.updated_at.utc
json.url workspace_memory_url(memory.workspace, memory)
json.workspace do
  json.id memory.workspace.id
  json.name memory.workspace.name
  json.state memory.workspace.status
  json.url workspace_url(memory.workspace)
end
