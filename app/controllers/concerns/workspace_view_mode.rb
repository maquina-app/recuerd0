module WorkspaceViewMode
  extend ActiveSupport::Concern

  VIEW_MODE_COOKIE = :recuerd0_workspace_view
  VIEW_MODES = %w[list grid].freeze

  MEMORY_VIEW_COOKIE = :recuerd0_memory_view
  MEMORY_VIEWS = %w[cards compact].freeze

  private

  # Resolves the workspace list view mode ("list" or "grid"), shared across the
  # active, archived, and deleted index pages so a user's preference carries over.
  def resolve_workspace_view_mode
    resolve_view_mode(VIEW_MODE_COOKIE, VIEW_MODES, "list")
  end

  # Resolves the memory view mode ("cards" or "compact") for the workspace#show
  # page, shared across active, archived, and deleted show pages.
  def resolve_memory_view_mode
    resolve_view_mode(MEMORY_VIEW_COOKIE, MEMORY_VIEWS, "cards")
  end

  # Generic view-mode resolver. A `view` param (when valid for `allowed`) sets and
  # persists the preference cookie; otherwise the cookie is read, defaulting to
  # `default`.
  def resolve_view_mode(cookie, allowed, default)
    if params[:view].in?(allowed)
      cookies[cookie] = {value: params[:view], expires: 1.year, httponly: true, same_site: :lax}
      params[:view]
    elsif cookies[cookie].in?(allowed)
      cookies[cookie]
    else
      default
    end
  end
end
