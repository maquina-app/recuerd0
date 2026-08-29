class SearchController < ApplicationController
  include ContentRenderable

  def index
    @query = params[:q].to_s.strip.first(query_max_length)

    if api_request?
      return render_validation_error("Query parameter is required") if @query.blank?
      return render_validation_error("Query must be at least #{Searchable::MIN_QUERY_LENGTH} characters") if @query.length < Searchable::MIN_QUERY_LENGTH
    end

    memories = build_search_scope
    @workspaces = matching_workspaces

    @pagy, @memories = pagy(memories, items: 10)

    if @query.present?
      track_event("search.query", metadata: {
        query: @query,
        results_count: @pagy.count,
        workspace_id: params[:workspace_id]
      })
    end

    respond_to do |format|
      format.html
      format.json do
        set_pagination_headers(@pagy)
        parse_grep_params if grep_mode?
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    raise unless api_request? && e.message.include?("fts5")
    render_validation_error("Invalid search query syntax")
  end

  private

  # ⌘K is the most habitual control in the app, so it must not be a dead end for
  # "open the workspace for the repo I'm in". Workspace hits are cheap (a LIKE
  # over a small, account-scoped table) and are shown above the memory results.
  WORKSPACE_RESULT_LIMIT = 5

  def matching_workspaces
    return Workspace.none if api_request? || @query.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    Current.account.workspaces
      .where("workspaces.name LIKE :term OR workspaces.description LIKE :term", term: term)
      .order(Arel.sql("workspaces.deleted_at IS NOT NULL, workspaces.archived_at IS NOT NULL, workspaces.updated_at DESC"))
      .limit(WORKSPACE_RESULT_LIMIT)
  end

  def build_search_scope
    scope = Memory.joins(:workspace)
      .where(workspaces: {account_id: Current.account.id})
      .latest_versions

    scope = if api_request?
      scope.api_search(@query)
    else
      scope.full_search(@query)
    end

    if api_request? && params[:workspace_id].present?
      workspace = Current.account.workspaces.find(params[:workspace_id])
      scope = scope.where(workspace: workspace)
    end

    scope = scope.by_category(params[:category])

    scope.order("memories.updated_at DESC")
      .includes(:content, :workspace, :child_versions)
  end

  def query_max_length
    api_request? ? 100 : 30
  end
end
