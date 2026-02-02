class Memories::VersionsController < ApplicationController
  before_action :set_workspace
  before_action :set_memory

  def index
    @all_versions = @memory.all_versions.includes(:content).order(:version)
    @root_memory = @memory.root_memory
  end

  def show
    @version = @memory.all_versions.find(params[:id])
    @all_versions = @memory.all_versions.includes(:content).order(:version)
  end

  def create
    unless @workspace.active?
      redirect_to [@workspace, @memory],
        alert: "Cannot create versions in #{@workspace.deleted? ? "deleted" : "archived"} workspace."
      return
    end

    @new_version = CreateMemoryVersion.call(@memory, version_params)

    if @new_version.persisted?
      redirect_to [@workspace, @new_version], notice: "New version created successfully."
    else
      flash[:alert] = "Failed to create new version."
      redirect_to [@workspace, @memory]
    end
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.with_deleted.find(params[:workspace_id])
  end

  def set_memory
    @memory = @workspace.memories.find(params[:memory_id])
  end

  def version_params
    params.require(:version).permit(:title, :source, :content, tags: [])
  end
end
