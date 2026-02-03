module WorkspacesHelper
  def workspace_link_path(workspace)
    if workspace.active?
      workspace_path(workspace)
    elsif workspace.archived?
      archived_workspace_path(workspace)
    elsif workspace.deleted?
      deleted_workspace_path(workspace)
    end
  end
end
