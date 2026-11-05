class Memories::VersionsController < ApplicationController
  include WorkspaceScoped
  include MemoryPayload

  allow_token_authentication

  wrap_parameters :version

  before_action :set_workspace
  before_action :ensure_not_deleted
  before_action :set_memory
  before_action :require_active_workspace, only: %i[create]
  before_action -> { reject_misshaped_fields(:version) }, only: %i[create]

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
          render "memories/show", status: :created, location: workspace_memory_url(@workspace, @new_version)
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

  # Every field is optional, so an absent or empty version is fine and inherits
  # everything. Only one of the wrong shape, such as a bare string, is refused.
  def version_params
    return {} if params[:version].blank?

    params.expect(version: [:title, :content, :source, :category, tags: []])
  end
end
