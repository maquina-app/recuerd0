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
    @memory_sort = params[:sort].presence_in(%w[created title]) # nil => "updated" default
    @category = params[:category].presence_in(Memory::CATEGORIES)
    @memory_query = params[:q].to_s.strip

    base = @workspace.memories.latest_versions.includes(:content, :pins, child_versions: :content)
    @category_counts = base.group(:category).count
    @category_counts.default = 0

    scope = base.by_category(@category)
    scope = scope.search(@memory_query) if @memory_query.present?
    scope = scope.ordered_by(@memory_sort)

    @pagy, @memories = pagy(scope, items: 10)
    @pinned_memories, @regular_memories = @memories.partition { |m| m.pinned_by?(Current.user) }
  end
end
