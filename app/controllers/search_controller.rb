class SearchController < ApplicationController
  include ContentRenderable
  include MemoryFilterable
  include ObsoleteFilterable

  allow_token_authentication

  def index
    @query = params[:q].to_s.strip.first(query_max_length)

    return if api_request? && !validate_category_param!

    if api_request?
      return render_validation_error("Query parameter is required") if @query.blank?
      return render_validation_error("Query must be at least #{Searchable::MIN_QUERY_LENGTH} characters") if @query.length < Searchable::MIN_QUERY_LENGTH
    end

    # An empty palette used to open onto a blank field, so every visit started
    # from recall: you had to already know what a memory was called. The things
    # a user has deliberately pinned, plus what they touched most recently, are
    # better defaults than nothing and cost two small account-scoped queries.
    return render_palette_suggestions if palette_frame? && @query.blank?

    memories = build_search_scope
    @obsolete_hidden_count = obsolete_hidden_count
    @inactive_hidden_count = inactive_hidden_count
    @workspaces = matching_workspaces

    @pagy, @memories = pagy(memories, items: 10)

    if @query.present?
      track_event("search.query", metadata: {
        query: @query,
        results_count: @pagy.count,
        workspace_id: params[:workspace_id]
      })
    end

    respond_to do |format|
      # The ⌘K palette points a turbo-frame at this same action, so the palette
      # and the full page can never disagree about what matches. A frame request
      # gets the compact list; everything else gets the page. With JS off there
      # is no frame, so the form submits and /search renders normally.
      format.html { render :palette, layout: false if palette_frame? }
      format.json do
        set_pagination_headers(@pagy)
        parse_grep_params if grep_mode?
      end
    end
  rescue ActiveRecord::StatementInvalid => e
    raise unless e.message.include?("fts5")
    return render_validation_error("Invalid search query syntax") if api_request?

    @invalid_query = true
    @workspaces = Workspace.none
    @pagy, @memories = pagy(Memory.none, items: 10)
    if palette_frame?
      render :palette, layout: false
    else
      render :index
    end
  end

  private

  # ⌘K is the most habitual control in the app, so it must not be a dead end for
  # "open the workspace for the repo I'm in". Workspace hits are cheap (a LIKE
  # over a small, account-scoped table) and are shown above the memory results.
  WORKSPACE_RESULT_LIMIT = 5

  SUGGESTION_LIMIT = 5

  def render_palette_suggestions
    @obsolete_hidden_count = 0
    @inactive_hidden_count = 0
    @suggested_workspaces = Current.user.pinned_workspaces
      .where(account_id: Current.account.id)
      .limit(SUGGESTION_LIMIT)

    pinned = apply_obsolete_filter(Current.user.pinned_memories.includes(:workspace))
      .limit(SUGGESTION_LIMIT)
      .to_a
    @suggested_memories = if pinned.size >= SUGGESTION_LIMIT
      pinned
    else
      # Top up with recent work so a user who has pinned nothing still opens
      # onto something actionable rather than an empty panel.
      recent = apply_obsolete_filter(
        Memory.in_active_workspaces_of(Current.account).latest_versions
      )
        .where.not(id: pinned.map(&:id))
        .preloaded
        .recently_updated
        .limit(SUGGESTION_LIMIT - pinned.size)
      pinned + recent.to_a
    end

    render :palette, layout: false
  end

  # Frame id lives in shared/_search_command_dialog; keep the two in step.
  PALETTE_FRAME_ID = "search_command_results"

  def palette_frame?
    request.headers["Turbo-Frame"] == PALETTE_FRAME_ID
  end
  helper_method :palette_frame?

  def matching_workspaces
    return Workspace.none if api_request? || @query.blank?
    # Scoped to one workspace, "jump to a workspace" is not the question being
    # asked, so the workspace block would just be noise above the memories.
    return Workspace.none if params[:workspace_id].present?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
    Current.account.workspaces
      .where("workspaces.name LIKE :term OR workspaces.description LIKE :term", term: term)
      .order(Arel.sql("workspaces.deleted_at IS NOT NULL, workspaces.archived_at IS NOT NULL, workspaces.updated_at DESC"))
      .limit(WORKSPACE_RESULT_LIMIT)
  end

  def build_search_scope
    apply_inactive_filter(apply_obsolete_filter(unfiltered_search_scope))
  end

  # How many matches the default filter withheld. One extra query, and only
  # when it can be non-zero: never when the flag is on, never without a query.
  def obsolete_hidden_count
    return 0 if include_obsolete? || @query.blank?

    unfiltered_search_scope.only_obsolete.count
  end

  # The inactive twin. Counted with the obsolete filter applied so the two
  # numbers describe disjoint sets and never add up to more than was withheld.
  def inactive_hidden_count
    return 0 if include_inactive? || @query.blank?

    apply_obsolete_filter(unfiltered_search_scope)
      .where("workspaces.archived_at IS NOT NULL OR workspaces.deleted_at IS NOT NULL")
      .count
  end

  def unfiltered_search_scope
    scope = Memory.joins(:workspace)
      .where(workspaces: {account_id: Current.account.id})
      .latest_versions

    # The browser gets the same FTS5 operators as the API. The audience is
    # people who think in queries, and `sqlite kamal` returning nothing because
    # the whole string was quoted as one phrase read as a broken index. Invalid
    # syntax is caught in #index and reported, rather than being pre-empted by
    # neutering the query.
    scope = scope.api_search(@query)

    if params[:workspace_id].present?
      workspace = Current.account.workspaces.find(params[:workspace_id])
      scope = scope.where(workspace: workspace)
    end

    scope = scope.by_category(params[:category])

    scope.order("memories.updated_at DESC")
      .includes(:content, :workspace, :child_versions)
  end

  # One cap for both formats. They used to differ (30 for HTML, 100 for API),
  # which meant the palette's maxlength="100" let a user type 70 characters the
  # server then dropped without a word — and because search is phrase-capable,
  # a truncated query returns silence rather than an error.
  QUERY_MAX_LENGTH = 100

  def query_max_length
    QUERY_MAX_LENGTH
  end
end
