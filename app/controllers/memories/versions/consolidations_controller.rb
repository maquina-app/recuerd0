class Memories::Versions::ConsolidationsController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace
  before_action :set_memory
  before_action :require_active_workspace

  def create
    @keep_version = @memory.all_versions.find(params[:version_id])
    @keep_version.consolidate_versions!

    redirect_to [@workspace, @keep_version], notice: t(".created")
  end

  private

  def set_memory
    @memory = @workspace.memories.find(params[:memory_id])
  end

  def require_active_workspace
    return if @workspace.active?

    redirect_to [@workspace, @memory], alert: t("memories.versions.read_only")
  end
end
