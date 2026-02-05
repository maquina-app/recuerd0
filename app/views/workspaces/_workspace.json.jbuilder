json.cache! workspace do
  json.call(workspace, :id, :name, :description, :memories_count)
  json.archived workspace.archived?
  json.created_at workspace.created_at.utc
  json.updated_at workspace.updated_at.utc
  json.url workspace_url(workspace)
end
