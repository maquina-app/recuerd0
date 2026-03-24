class Memories::BrowseController < ApplicationController
  include MemoryFilterable

  def index
    scope = Memory.joins(:workspace)
      .where(workspaces: {account_id: Current.account.id, deleted_at: nil, archived_at: nil})
      .latest_versions
      .includes(:content, :workspace, child_versions: :content)

    scope = apply_memory_filters(scope)
    scope = scope.where(workspace_id: params[:workspace_id]) if params[:workspace_id].present?

    @pagy, @memories = pagy(scope, limit: permitted_per_page)
    @memories = @memories.map { |m| m.versioned? ? m.current_version : m }
    set_pagination_headers(@pagy)

    render "memories/index"
  end
end
