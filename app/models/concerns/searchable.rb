module Searchable
  extend ActiveSupport::Concern

  MIN_QUERY_LENGTH = 3

  included do
    after_save_commit :update_search_index
    after_destroy_commit :delete_search_index

    # One query language for web, API and MCP: FTS5 operators (AND, OR, NOT,
    # "phrase", title:term, body:term, grouping) over safely quoted words.
    scope :full_search, ->(query) {
      return none if query.blank? || query.length < MIN_QUERY_LENGTH

      expression = fts_expression(query)
      matches = joins("INNER JOIN memories_search ON memories_search.memory_id = memories.id")
        .order(Arel.sql("memories_search.rank"))

      # Nothing searchable (only operators): still empty, but the join stays so
      # Memory.search can embed this relation and read its rank column.
      expression.present? ? matches.where("memories_search MATCH ?", expression) : matches.none
    }
  end

  FTS_OPERATORS = %w[AND OR NOT].freeze
  FTS_SYNTAX = ["(", ")", *FTS_OPERATORS].freeze
  FTS_COLUMN_FILTER = /\A(title|body):(.+)\z/

  class_methods do
    # Turns what a person or agent typed into an FTS5 expression that cannot be
    # a syntax error. Every bare word is quoted, so `deploy.sh` or
    # `maquina-components` is searched for rather than parsed; operators,
    # phrases, parentheses and column filters keep their meaning. When the
    # operators themselves don't parse (`kamal OR`, `(sqlite`), the words are
    # searched on their own, ANDed, instead of failing the request.
    def fts_expression(query)
      tokens = query.to_s.scan(/"[^"]*"?|[()]|[^\s()"]+/)

      expression = fts_join(tokens.filter_map { |token| fts_token(token) })
      return expression if fts_expression_valid?(expression)

      fts_join(tokens.excluding(FTS_SYNTAX).filter_map { |token| fts_token(token) })
    end

    private

    # FTS5 only applies its implicit AND between plain phrases; `(a OR b) notes`
    # is a syntax error. Spelling the AND out between adjacent operands means
    # the same thing (same precedence) and lets grouping sit next to words.
    def fts_join(parts)
      parts.each_with_object([]) do |part, joined|
        if joined.any? && !joined.last.in?(["(", *FTS_OPERATORS]) && !part.in?([")", *FTS_OPERATORS])
          joined << "AND"
        end
        joined << part
      end.join(" ")
    end

    def fts_token(token)
      case token
      when *FTS_SYNTAX then token
      when /\A"/ then fts_phrase(token.delete('"'))
      when FTS_COLUMN_FILTER then "#{$1}:#{fts_phrase($2)}"
      else fts_phrase(token.delete_suffix("*"))
      end
    end

    # The trigram tokenizer already matches inside words, so a trailing `*`
    # prefix marker adds nothing and is dropped rather than quoted literally.
    def fts_phrase(text)
      %("#{text}") if text.present?
    end

    def fts_expression_valid?(expression)
      return false if expression.blank?

      connection.select_value(
        sanitize_sql_array(["SELECT 1 FROM memories_search WHERE memories_search MATCH ? LIMIT 1", expression])
      )
      true
    rescue ActiveRecord::StatementInvalid
      false
    end
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

    body = newest.content&.body&.content.to_s
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
