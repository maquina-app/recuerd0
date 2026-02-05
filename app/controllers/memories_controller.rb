class MemoriesController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace
  before_action :set_memory, only: %i[show edit update destroy]
  before_action :require_active_workspace, only: %i[new create edit update destroy]
  before_action :require_full_access, only: %i[create update destroy], if: :api_request?

  def index
    scope = @workspace.memories
      .latest_versions
      .includes(:content)
      .order(updated_at: :desc)

    @pagy, @memories = pagy(scope, items: 25)

    respond_to do |format|
      format.html { redirect_to workspace_path(@workspace) }
      format.json { set_pagination_headers(@pagy) }
    end
  end

  def show
    @all_versions = @memory.all_versions

    respond_to do |format|
      format.html do
        fresh_when_private(
          etag: [@memory, @all_versions.maximum(:updated_at)],
          last_modified: @memory.updated_at
        )
      end
      format.json
    end
  end

  def new
    @memory = @workspace.memories.build
  end

  def create
    @memory = Memory.create_with_content(@workspace, memory_params)

    if @memory.persisted?
      respond_to do |format|
        format.html { redirect_to [@workspace, @memory], notice: t(".created") }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = t(".errors")
          render :new, status: :unprocessable_entity
        end
        format.json { render_validation_errors(@memory) }
      end
    end
  end

  def edit
    # Ensure content exists before editing
    @memory.content || @memory.create_content(body: "")
  end

  def update
    @memory.update_with_content(memory_params)

    if @memory.errors.empty?
      respond_to do |format|
        format.html { redirect_to [@workspace, @memory], notice: t(".updated") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = t(".errors")
          render :edit, status: :unprocessable_entity
        end
        format.json { render_validation_errors(@memory) }
      end
    end
  end

  def destroy
    @memory.destroy

    respond_to do |format|
      format.html { redirect_to workspace_path(@workspace), notice: t(".destroyed"), status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def set_memory
    @memory = @workspace.memories.find(params[:id])
  end

  def require_active_workspace
    return if @workspace.active?

    respond_to do |format|
      format.html { redirect_to workspace_path(@workspace), alert: t("workspaces.inactive_workspace") }
      format.json do
        render json: {
          error: {code: "FORBIDDEN", message: "Workspace is not active", status: 403}
        }, status: :forbidden
      end
    end
  end

  def memory_params
    params.require(:memory).permit(:title, :source, :content, tags: [])
  end
end
