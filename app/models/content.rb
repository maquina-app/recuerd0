class Content < ApplicationRecord
  belongs_to :memory, touch: true

  after_save_commit :reindex_memory

  private

  def reindex_memory
    memory.rebuild_search_index if memory.respond_to?(:rebuild_search_index)
  end
end
