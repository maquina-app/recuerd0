class Memories::VersionsController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace
  before_action :set_memory
  before_action :require_active_workspace, only: %i[create]
  before_action :require_full_access, only: %i[create], if: :api_request?

  def index
    @all_versions = @memory.all_versions.includes(:content)
    @root_memory = @memory.root_memory
  end

  def show
    @version = @memory.all_versions.find(params[:id])
    @all_versions = @memory.all_versions.includes(:content)
  end

  def create
    @new_version = @memory.create_version!(version_params)

    if @new_version.persisted?
      track_event("version.create", resource: @new_version)
      respond_to do |format|
        format.html { redirect_to [@workspace, @new_version], notice: t(".created") }
        format.json do
          @memory = @new_version
          render "memories/show", status: :created
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to [@workspace, @memory], alert: t(".failed") }
        format.json { render_validation_errors(@new_version) }
      end
    end
  end

  private

  def set_memory
    @memory = @workspace.memories.find(params[:memory_id])
  end

  def require_active_workspace
    return if @workspace.active?

    respond_to do |format|
      format.html { redirect_to [@workspace, @memory], alert: t("memories.versions.read_only") }
      format.json { render_forbidden("Workspace is not active") }
    end
  end

  def version_params
    params.fetch(:memory, {}).permit(:title, :content, :source, tags: [])
  end
end
