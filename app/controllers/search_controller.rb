class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip.first(30)

    memories = Memory.joins(:workspace)
      .where(workspaces: {user_id: Current.user.id})
      .latest_versions
      .full_search(@query)
      .order("memories.updated_at DESC")
      .includes(:content, :workspace, :child_versions)

    @pagy, @memories = pagy(memories, items: 10)
  end
end
