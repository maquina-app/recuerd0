module WorkspaceViewMode
  extend ActiveSupport::Concern

  VIEW_MODE_COOKIE = :recuerd0_workspace_view
  VIEW_MODES = %w[list grid].freeze

  private

  # Resolves the workspace list view mode ("list" or "grid"), shared across the
  # active, archived, and deleted index pages so a user's preference carries over.
  # A `view` param sets and persists the preference; otherwise the cookie is read,
  # defaulting to "list".
  def resolve_workspace_view_mode
    if params[:view].in?(VIEW_MODES)
      cookies[VIEW_MODE_COOKIE] = {value: params[:view], expires: 1.year, httponly: true, same_site: :lax}
      params[:view]
    elsif cookies[VIEW_MODE_COOKIE].in?(VIEW_MODES)
      cookies[VIEW_MODE_COOKIE]
    else
      "list"
    end
  end
end
