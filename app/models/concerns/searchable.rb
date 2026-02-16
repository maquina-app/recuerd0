module Searchable
  extend ActiveSupport::Concern

  MIN_QUERY_LENGTH = 3

  included do
    after_save_commit :update_search_index
    after_destroy_commit :delete_search_index

    scope :full_search, ->(query) {
      return none if query.blank? || query.length < MIN_QUERY_LENGTH

      # Quote the query as an FTS5 phrase to neutralize special syntax characters
      sanitized = '"' + query.gsub('"', '""') + '"'

      joins("INNER JOIN memories_search ON memories_search.memory_id = memories.id")
        .where("memories_search MATCH ?", sanitized)
        .order(Arel.sql("memories_search.rank"))
    }

    # API search: passes raw FTS5 query with full operator support
    # (AND, OR, NOT, "phrase", title:term, body:term, grouping)
    scope :api_search, ->(query) {
      return none if query.blank? || query.length < MIN_QUERY_LENGTH

      joins("INNER JOIN memories_search ON memories_search.memory_id = memories.id")
        .where("memories_search MATCH ?", query)
        .order(Arel.sql("memories_search.rank"))
    }
  end

  def rebuild_search_index
    update_search_index
  end

  private

  def update_search_index
    root = root_memory
    newest = root.child_versions.includes(:content).order(version: :desc).first || root

    self.class.connection.exec_delete(
      "DELETE FROM memories_search WHERE memory_id = ?",
      "FTS Delete", [root.id]
    )

    body = newest.content&.body || ""
    self.class.connection.exec_insert(
      "INSERT INTO memories_search(title, body, memory_id) VALUES (?, ?, ?)",
      "FTS Insert", [newest.title || "", body, root.id]
    )
  end

  def delete_search_index
    root_id = root_version? ? id : parent_memory_id
    self.class.connection.exec_delete(
      "DELETE FROM memories_search WHERE memory_id = ?",
      "FTS Delete", [root_id]
    )
  end
end
