class Memories::PinnedController < ApplicationController
  SORTS = %w[pinned updated title].freeze
  DEFAULT_SORT = "pinned"

  def index
    @view = (params[:view] == "compact") ? "compact" : "cards"
    @sort = SORTS.include?(params[:sort]) ? params[:sort] : DEFAULT_SORT

    scope = Current.user.pinned_memories.includes(preloads)

    # Counts come from the unfiltered set so the chips keep reporting the whole
    # picture while one of them is active.
    all_pinned = scope.to_a
    @workspace_counts = all_pinned.group_by(&:workspace).transform_values(&:size)
      .sort_by { |workspace, _| workspace.name.downcase }
    @total_count = all_pinned.size
    @pin_budget = User::PIN_LIMIT
    @pins_used = Current.user.pinned_items_count
    @system_pins_used = Current.user.system_pinned_items_count
    # One lookup for the whole page rather than a per-row origin read: a user
    # holds few pins, and the rows are grouped and re-sorted before rendering.
    @pin_origins = Current.user.pins.for_memories.pluck(:pinnable_id, :origin).to_h

    @workspace_filter = Current.account.workspaces.find_by(id: params[:workspace_id])
    memories = @workspace_filter ? all_pinned.select { |m| m.workspace_id == @workspace_filter.id } : all_pinned

    # No pager: PIN_LIMIT caps a user at ten pins across workspaces and
    # memories combined, so with the old `items: 10` a second page was
    # unreachable in normal use — the control was dead UI. Rendering the whole
    # set is both correct and shorter.
    @memories = sort_memories(memories)
    # group_by alone leaves group order as "whichever workspace's first item
    # happened to land first", so ?sort=title rendered headings B, S, F, S, R
    # directly under an alphabetical chip row. Order the groups by the same key
    # the items are sorted by.
    @grouped = sort_groups(@memories.group_by(&:workspace))

    # The set a user curates here is the one thing an agent would actually want
    # to fetch, and it had no JSON representation at all — the page assembled a
    # cross-workspace context set that nothing could consume. Scoped to
    # Current.user like every other pin lookup, never to the account.
    respond_to do |format|
      format.html
      format.json { @memories = @memories.map { |m| m.versioned? ? m.current_version : m } }
    end
  end

  private

  def preloads
    # Every one of these was an N+1 in the card partial: versioned? and
    # current_version walk child_versions, links_count hits both link sides,
    # and the actions menu asked pinned_by? per row. Preloading :content alone
    # was also near-useless — a versioned memory renders the child's content.
    [:workspace, :pins, :outgoing_links, :incoming_links, :content, {child_versions: :content}]
  end

  def sort_memories(memories)
    case @sort
    when "updated" then memories.sort_by { |m| -m.updated_at.to_i }
    when "title" then memories.sort_by { |m| display_version_of(m).display_title.to_s.downcase }
    else memories # pins.created_at DESC, from the association
    end
  end

  def sort_groups(grouped)
    case @sort
    when "title" then grouped.sort_by { |workspace, _| workspace.name.downcase }.to_h
    when "updated" then grouped.sort_by { |_, memories| -memories.map { |m| m.updated_at.to_i }.max }.to_h
    else grouped # most-recently-pinned first, inherited from the item order
    end
  end

  def display_version_of(memory)
    memory.versioned? ? memory.current_version : memory
  end
end
