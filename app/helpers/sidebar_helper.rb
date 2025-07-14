module SidebarHelper
  def sidebar_link_class(path)
    # Check for exact match first
    return "true" if current_page?(path)

    # Check for workspace-specific matches
    if path =~ /^\/workspaces\/(\d+)$/
      workspace_id = $1
      current_path = request.path

      # Match archived workspace show page
      return "true" if current_path == "/workspaces/archived/#{workspace_id}"

      # Match deleted workspace show page
      return "true" if current_path == "/workspaces/deleted/#{workspace_id}"
    end

    "false"
  end
end
