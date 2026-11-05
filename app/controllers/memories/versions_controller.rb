class Memories::VersionsController < ApplicationController
  include WorkspaceScoped
  include MemoryPayload
  include MemoryPage

  allow_token_authentication

  wrap_parameters :version

  before_action :set_workspace
  before_action :ensure_not_deleted
  before_action :set_memory
  before_action :require_active_workspace, only: %i[create]
  before_action -> { reject_misshaped_fields(:version) }, only: %i[create]

  def index
    @all_versions = @memory.all_versions.includes(:content, :created_by).to_a
    @root_memory = @memory.root_memory
    @current_version = @all_versions.last
  end

  # The same page as the memory itself, so a version reads the way it will read
  # if it comes back, rendered rather than as raw source.
  def show
    version = @memory.all_versions.find(params[:id])

    respond_to do |format|
      format.html do
        prepare_memory_page(version)
        render "memories/show"
      end
      format.json { @version = version }
    end
  end

  # Omitted fields come from the version in the URL. The memory's own id means its
  # current version, the same as every other surface, and never v1. A specific
  # version's id means that version. A result identical to the current version is
  # refused.
  def create
    @new_version = @memory.resolve_current_version.create_changed_version(
      version_params.to_h.symbolize_keys.merge(created_by: Current.user)
    )

    if @new_version.persisted?
      track_event("version.create", resource: @new_version)
      respond_to do |format|
        format.html { redirect_to workspace_memory_path(@workspace, @memory.stable_id), notice: t(".created") }
        format.json do
          @memory = @new_version
          render "memories/show", status: :created, location: workspace_memory_url(@workspace, @new_version)
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to workspace_memory_path(@workspace, @memory.stable_id), alert: t(".failed") }
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
      format.html { redirect_to workspace_memory_path(@workspace, @memory.stable_id), alert: t("memories.versions.read_only") }
      format.json { render_forbidden("Workspace is not active") }
    end
  end

  # Every field is optional, so an absent or empty version is fine and inherits
  # everything. Only one of the wrong shape, such as a bare string, is refused.
  def version_params
    return {} if params[:version].blank?

    params.expect(version: [:title, :content, :source, :category, :change_note, tags: []])
  end
end
