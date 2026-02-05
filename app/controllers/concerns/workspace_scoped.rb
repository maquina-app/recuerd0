module WorkspaceScoped
  extend ActiveSupport::Concern

  private

  def set_workspace
    @workspace = Current.account.workspaces.find(params[:workspace_id] || params[:id])
  end

  def require_active_workspace
    return if @workspace.active?

    redirect_to workspaces_path, alert: t("workspaces.inactive_workspace")
  end

  def load_workspace_memories(scope = nil)
    scope ||= @workspace.memories.includes(:content, :pins).order(created_at: :desc)
    @pagy, @memories = pagy(scope, items: 10)
    @pinned_memories, @regular_memories = @memories.partition { |m| m.pinned_by?(Current.user) }
  end
end
