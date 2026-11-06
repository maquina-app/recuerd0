module Workspaces
  class ContextResolver
    PRELOADS = [
      :content,
      :pins,
      :workspace,
      {child_versions: :content}
    ].freeze

    def self.call(workspace:, user: nil, limit: 10, category: nil, include_obsolete: false)
      new(workspace:, user:, limit:, category:, include_obsolete:).call
    end

    def initialize(workspace:, user:, limit:, category:, include_obsolete: false)
      @workspace = workspace
      @user = user
      @limit = limit
      @category = category
      @include_obsolete = include_obsolete
    end

    def call
      if user
        pins = workspace.memories
          .joins(:pins)
          .where(pins: {user_id: user.id})
          .order(Arel.sql("pins.created_at DESC"))
          .pluck(:id, :parent_memory_id, Arel.sql("pins.origin"))
          .map { |id, parent_memory_id, origin| [parent_memory_id || id, origin] }
        pinned_root_ids = pins.map(&:first).uniq
        chosen_root_ids = pins.filter_map { |root_id, origin| root_id unless origin == "system" }

        pinned_roots_by_id = visible(workspace.memories.latest_versions)
          .where(id: pinned_root_ids)
          .by_category(category)
          .includes(*PRELOADS)
          .index_by(&:id)
        pinned_roots = pinned_root_ids.filter_map { |id| pinned_roots_by_id[id] }
        prioritized, rest = pinned_roots.partition(&:default_pinned)
        pinned_roots = prioritized + rest

        total_pinned = pinned_roots.size
        if pinned_roots.any? { |memory| chosen_root_ids.include?(memory.id) }
          return {
            memories: pinned_roots.first(limit),
            source: "pins",
            total_pinned: total_pinned
          }
        end

        # Only pins recuerd0 placed, such as the seeded Map. Nobody chose those as
        # this workspace's context, so they lead the workspace's own memories rather
        # than replacing them: an agent should wake on the how-to page and the content.
        # Seeded memories don't top up, so a fresh account still wakes on just its pins.
        if total_pinned.positive?
          placed = pinned_roots.first(limit)
          own = recent(limit - placed.size, workspace.memories.where("memories.source IS NOT 'system'"))
          return {
            memories: placed + own,
            source: own.any? ? "recent" : "pins",
            total_pinned: total_pinned
          }
        end
      end

      {memories: recent(limit), source: "recent", total_pinned: 0}
    end

    private

    def recent(limit, memories = workspace.memories)
      visible(memories.latest_versions)
        .by_category(category)
        .order(updated_at: :desc)
        .includes(*PRELOADS)
        .limit(limit)
        .to_a
    end

    # Obsolete memories are retired knowledge: a session woken on them starts
    # from a decision that was reversed. Pins included — a pinned-and-obsolete
    # memory stays reachable from the workspace list.
    def visible(scope)
      @include_obsolete ? scope : scope.without_obsolete
    end

    attr_reader :workspace, :user, :limit, :category
  end
end
