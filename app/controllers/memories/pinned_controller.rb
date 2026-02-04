class Memories::PinnedController < ApplicationController
  def index
    @pagy, @memories = pagy(
      Current.user.pinned_memories.includes(:content, :workspace),
      items: 10
    )
  end
end
