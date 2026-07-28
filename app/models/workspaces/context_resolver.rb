module Workspaces
  class ContextResolver
    PRELOADS = [
      :content,
      :pins,
      :workspace,
      {child_versions: :content}
    ].freeze

    def self.call(workspace:, user: nil, limit: 10, category: nil)
      new(workspace:, user:, limit:, category:).call
    end

    def initialize(workspace:, user:, limit:, category:)
      @workspace = workspace
      @user = user
      @limit = limit
      @category = category
    end

    def call
      if user
        pinned_root_ids = workspace.memories
          .joins(:pins)
          .where(pins: {user_id: user.id})
          .order(Arel.sql("pins.created_at DESC"))
          .pluck(:id, :parent_memory_id)
          .map { |id, parent_memory_id| parent_memory_id || id }
          .uniq

        pinned_roots_by_id = workspace.memories
          .latest_versions
          .where(id: pinned_root_ids)
          .by_category(category)
          .includes(*PRELOADS)
          .index_by(&:id)
        pinned_roots = pinned_root_ids.filter_map { |id| pinned_roots_by_id[id] }
        prioritized, rest = pinned_roots.partition(&:default_pinned)
        pinned_roots = prioritized + rest

        total_pinned = pinned_roots.size
        if total_pinned.positive?
          return {
            memories: pinned_roots.first(limit),
            source: "pins",
            total_pinned: total_pinned
          }
        end
      end

      recent = workspace.memories
        .latest_versions
        .by_category(category)
        .order(updated_at: :desc)
        .includes(*PRELOADS)
        .limit(limit)
        .to_a

      {memories: recent, source: "recent", total_pinned: 0}
    end

    private

    attr_reader :workspace, :user, :limit, :category
  end
end
