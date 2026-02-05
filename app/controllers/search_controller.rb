class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip.first(query_max_length)

    if api_request?
      return render_query_error("Query parameter is required") if @query.blank?
      return render_query_error("Query must be at least #{Searchable::MIN_QUERY_LENGTH} characters") if @query.length < Searchable::MIN_QUERY_LENGTH
    end

    memories = build_search_scope

    @pagy, @memories = pagy(memories, items: 10)

    respond_to do |format|
      format.html
      format.json { set_pagination_headers(@pagy) }
    end
  rescue ActiveRecord::StatementInvalid => e
    raise unless api_request? && e.message.include?("fts5")
    render_query_error("Invalid search query syntax")
  end

  private

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

    scope.order("memories.updated_at DESC")
      .includes(:content, :workspace, :child_versions)
  end

  def query_max_length
    api_request? ? 100 : 30
  end

  def render_query_error(message)
    render json: {
      error: {code: "VALIDATION_ERROR", message: message, status: 422}
    }, status: :unprocessable_entity
  end
end
