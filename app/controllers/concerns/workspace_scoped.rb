module WorkspaceScoped
  extend ActiveSupport::Concern

  private

  def set_workspace
    @workspace = Current.account.workspaces.find(params[:workspace_id] || params[:id])
  end

  # A soft-deleted workspace is named explicitly in the URL, so its JSON
  # resources answer 404 rather than 403: deletion has to mean what the
  # confirmation dialog promised. HTML is untouched — the deleted-workspace page
  # is the recovery route. Mirrors Workspaces::ContextsController, which set the
  # convention alongside stats and merge candidates.
  def ensure_not_deleted
    return unless @workspace.deleted?

    render_not_found if request.format.json?
  end

  def require_active_workspace
    return if @workspace.active?

    respond_to do |format|
      format.html { redirect_to workspaces_path, alert: t("workspaces.inactive_workspace") }
      format.json { render_forbidden("Workspace is not active") }
    end
  end

  def load_workspace_memories
    @memory_view = resolve_memory_view_mode
    @memory_tag = params[:tag].presence

    # A tag filter replaces category/search (single active filter at a time).
    # Ignoring them here is defense in depth against a crafted URL carrying both.
    if @memory_tag
      @category = nil
      @memory_query = ""
    else
      @category = params[:category].presence_in(Memory::CATEGORIES)
      @memory_query = Memory.normalize_search_query(params[:q])
    end
    @memory_sort_param = params[:sort].presence_in(Memory::SEARCH_SORTS)

    base = @workspace.memories.latest_versions.includes(:content, :pins, child_versions: :content)

    # Counts must answer "how many would this category give me *now*", so they
    # respect every active filter except the category itself. Counting the
    # unfiltered set made the chips read "All 5" directly above "nothing
    # matched".
    counting_scope = base
    counting_scope = counting_scope.by_tag(@memory_tag) if @memory_tag
    counting_scope = counting_scope.search(@memory_query) if @memory_query.present?
    @category_counts = counting_scope.group(:category).count
    @category_counts.default = 0

    scope = base.by_category(@category)
    scope = scope.by_tag(@memory_tag) if @memory_tag
    scope = scope.search(@memory_query) if @memory_query.present?
    @memory_sort = Memory.resolve_sort(@memory_sort_param, query: @memory_query)
    scope = scope.ordered_by(@memory_sort)

    @pagy, @memories = pagy(scope, items: 10)
    @pinned_memories, @regular_memories = @memories.partition { |m| m.pinned_by?(Current.user) }
  end
end
