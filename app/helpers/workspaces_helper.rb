module WorkspacesHelper
  def workspace_view_mode
    @view_mode || "list"
  end

  def workspace_link_path(workspace)
    if workspace.active?
      workspace_path(workspace)
    elsif workspace.archived?
      archived_workspace_path(workspace)
    elsif workspace.deleted?
      deleted_workspace_path(workspace)
    end
  end

  # Show path for a workspace honoring its state (active/archived/deleted), with query params.
  def workspace_show_path(workspace, **params)
    helper = if workspace.archived?
      :archived_workspace_path
    elsif workspace.deleted?
      :deleted_workspace_path
    else
      :workspace_path
    end
    public_send(helper, workspace, **params.compact)
  end

  # Current memory filter params, with overrides, for building toolbar/pagination links.
  def memory_filter_params(overrides = {})
    {category: @category, sort: @memory_sort, q: @memory_query.presence, view: @memory_view}
      .merge(overrides).compact
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
