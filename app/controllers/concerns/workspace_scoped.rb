module WorkspaceScoped
  extend ActiveSupport::Concern

  private

  def set_workspace
    @workspace = Current.account.workspaces.find(params[:workspace_id] || params[:id])
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
    @category_counts = base.group(:category).count
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
