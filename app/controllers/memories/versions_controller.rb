class Memories::VersionsController < ApplicationController
  before_action :set_workspace
  before_action :set_memory
  before_action :require_active_workspace, only: %i[create destroy]

  def index
    @all_versions = @memory.all_versions.includes(:content)
    @root_memory = @memory.root_memory
  end

  def show
    @version = @memory.all_versions.find(params[:id])
    @all_versions = @memory.all_versions.includes(:content)
  end

  def create
    @new_version = @memory.create_version!

    if @new_version.persisted?
      redirect_to [@workspace, @new_version], notice: t(".created")
    else
      redirect_to [@workspace, @memory], alert: t(".failed")
    end
  end

  def destroy
    @keep_version = @memory.all_versions.find(params[:id])
    @keep_version.consolidate_versions!

    redirect_to [@workspace, @keep_version], notice: t(".destroyed")
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.with_deleted.find(params[:workspace_id])
  end

  def set_memory
    @memory = @workspace.memories.find(params[:memory_id])
  end

  def require_active_workspace
    return if @workspace.active?

    redirect_to [@workspace, @memory], alert: t("memories.versions.read_only")
  end
end
