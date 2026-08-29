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
    {category: @category, tag: @memory_tag, sort: @memory_sort_param, q: @memory_query.presence, view: @memory_view}
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

  # The tile's job is recognition, not quantity: 21 workspaces should be 21
  # distinguishable objects. The count already lives in the stat chip, in words.
  # Tone is a deterministic neutral step (never a second hue — The One Green
  # Rule), so the column has texture without the accent becoming a wash.
  WORKSPACE_TONES = 4

  def workspace_initial(workspace)
    workspace.name.to_s.strip.first&.upcase.presence || "?"
  end

  def workspace_tone(workspace)
    workspace.name.to_s.sum % WORKSPACE_TONES
  end

  # Staleness is relative to the account (Workspace.stale_threshold_for), so the
  # flag stays rare by construction instead of firing on every row.
  def workspace_freshness(workspace, stale_after:)
    return :current unless workspace.active?
    return :current if stale_after.blank?

    activity = workspace.last_activity
    return :current if activity.blank?

    (activity < stale_after) ? :stale : :current
  end
end
