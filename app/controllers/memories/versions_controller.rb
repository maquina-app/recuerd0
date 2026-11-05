class Memories::VersionsController < ApplicationController
  include WorkspaceScoped
  include MemoryPage

  allow_token_authentication

  wrap_parameters :version

  before_action :set_workspace
  before_action :ensure_not_deleted
  before_action :set_memory
  before_action :require_active_workspace, only: %i[create]

  def index
    @all_versions = @memory.all_versions.includes(:content, :created_by).to_a
    @root_memory = @memory.root_memory
    @current_version = @all_versions.last
  end

  # The same page as the memory itself, so a version reads the way it will read
  # if it comes back, rendered rather than as raw source.
  def show
    prepare_memory_page(@memory.all_versions.find(params[:id]))
    render "memories/show"
  end

  # A browser only reaches this through "Restore as new version", which copies
  # the version in the URL. Writing a new version goes through the editor.
  def create
    @new_version = @memory.create_version!(version_attributes)

    if @new_version.persisted?
      track_event("version.create", resource: @new_version)
      respond_to do |format|
        format.html do
          redirect_to workspace_memory_path(@workspace, @memory.stable_id),
            notice: t(".restored", from: @memory.version_label, version: @new_version.version_label)
        end
        format.json do
          @memory = @new_version
          render "memories/show", status: :created
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

  def version_params
    params.fetch(:version, {}).permit(:title, :content, :source, :category, :change_note, tags: [])
  end

  def version_attributes
    attributes = version_params.to_h.symbolize_keys.merge(created_by: Current.user)
    return attributes unless request.format.html?

    attributes.merge(change_note: t("memories.versions.create.restored_note", from: @memory.version_label))
  end
end
