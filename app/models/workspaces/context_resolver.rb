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
        pinned_scope = workspace.memories
          .latest_versions
          .joins(:pins)
          .where(pins: {user_id: user.id})
          .by_category(category)
          .order(Arel.sql("pins.created_at DESC"))

        total_pinned = pinned_scope.count
        if total_pinned.positive?
          return {
            memories: pinned_scope.includes(*PRELOADS).limit(limit).to_a,
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
