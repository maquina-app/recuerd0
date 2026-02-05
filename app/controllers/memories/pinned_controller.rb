class Memories::PinnedController < ApplicationController
  def index
    @pagy, @memories = pagy(
      Current.user.pinned_memories.includes(:content, :workspace),
      items: 10
    )

    fresh_when_private(
      etag: collection_cache_key(
        Current.user.pinned_memories,
        @pagy,
        Current.user.pins.where(pinnable_type: "Memory").maximum(:updated_at)
      ),
      last_modified: Current.user.pinned_memories.maximum(:updated_at)
    )
  end
end
