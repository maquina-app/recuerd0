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

  def workspace_breadcrumb_links(workspace)
    base = {"Workspaces" => workspaces_path}

    if workspace.archived?
      base.merge("Archived Workspaces" => archived_workspaces_path)
    elsif workspace.deleted?
      base.merge("Deleted Workspaces" => deleted_workspaces_path)
    else
      base
    end
  end
end
