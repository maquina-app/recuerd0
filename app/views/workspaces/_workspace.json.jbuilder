json.cache! workspace do
  json.call(workspace, :id, :name, :description, :memories_count)
  json.archived workspace.archived?
  json.created_at workspace.created_at.utc
  json.updated_at workspace.updated_at.utc
  json.url workspace_url(workspace)
end

# Outside the cache block for the same reason as memories/_memory.json.jbuilder:
# json.cache! is keyed on the workspace, and pins are per user.
json.pinned pinned_for?(workspace)
json.pinned_at pinned_at_for(workspace)
