class Memories::BrowseController < ApplicationController
  include MemoryFilterable
  include ObsoleteFilterable

  allow_token_authentication

  def index
    scope = active_workspace_memories
    scope = apply_memory_filters(scope)
    scope = scope.where(workspace_id: params[:workspace_id]) if params[:workspace_id].present?
    # Fetching by identity is never filtered: a caller naming ids already knows
    # what it wants, obsolete or not.
    scope = if batch_ids
      scope.where(id: batch_ids)
    else
      apply_obsolete_filter(scope)
    end

    @pagy, @memories = pagy(scope, limit: permitted_per_page)
    @memories = @memories.map { |m| m.versioned? ? m.current_version : m }
    set_pagination_headers(@pagy)

    render "memories/index"
  end

  private

  # Batch fetch by explicit IDs (comma-separated), e.g. ?ids=1,2,3 — the REST
  # counterpart to the read_memories MCP tool. Still account-scoped via
  # active_workspace_memories and paginated like any other browse response.
  def batch_ids
    return nil if params[:ids].blank?

    params[:ids].to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def active_workspace_memories
    Memory.joins(:workspace)
      .where(workspaces: {account_id: Current.account.id, deleted_at: nil, archived_at: nil})
      .latest_versions
      .includes(:content, :workspace, child_versions: :content)
  end
end
