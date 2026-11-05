# Nobody accepts a handover, so this is where someone can see what they answer for.
class Profile::OwnershipsController < ApplicationController
  def show
    @workspaces = Current.user.owned_workspaces.not_deleted.order(Arel.sql("LOWER(workspaces.name)"))
    @pagy, @memories = pagy(
      Current.user.owned_memories.in_undeleted_workspaces.preload(:workspace, :latest_version).reorder("memories.updated_at DESC")
    )
  end
end
