class WorkspacesController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace, only: %i[show edit update destroy]
  before_action :require_active_workspace, only: %i[edit update]
  before_action :require_full_access, only: %i[create update destroy], if: :api_request?

  def index
    workspaces = Current.account.workspaces
      .active
      .ordered_with_pins_first(Current.user)
      .includes(:pins)

    @pagy, @workspaces = pagy(workspaces)

    respond_to do |format|
      format.html do
        fresh_when_private(
          etag: collection_cache_key(
            Current.account.workspaces.active,
            @pagy,
            Current.user.pins.where(pinnable_type: "Workspace").maximum(:updated_at)
          ),
          last_modified: Current.account.workspaces.active.maximum(:updated_at)
        )
      end
      format.json { set_pagination_headers(@pagy) }
    end
  end

  def show
    respond_to do |format|
      format.html do
        if @workspace.archived?
          redirect_to archived_workspace_path(@workspace)
          return
        elsif @workspace.deleted?
          redirect_to deleted_workspace_path(@workspace)
          return
        end

        track_event("workspace.view", resource: @workspace)

        scope = @workspace.memories
          .latest_versions
          .includes(:content, :child_versions, :pins)
          .order(updated_at: :desc)

        load_workspace_memories(scope)

        fresh_when_private(
          etag: collection_cache_key(
            @workspace.memories,
            @pagy,
            @workspace.updated_at,
            Current.user.pins.where(pinnable_type: "Memory").maximum(:updated_at)
          ),
          last_modified: @workspace.updated_at
        )
      end
      format.json
    end
  end

  def new
    @workspace = Current.account.workspaces.build
  end

  def edit
  end

  def create
    @workspace = Current.account.workspaces.build(workspace_params)

    if @workspace.save
      track_event("workspace.create", resource: @workspace)
      respond_to do |format|
        format.html { redirect_to @workspace, notice: t(".created") }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = t(".errors")
          render :new, status: :unprocessable_entity
        end
        format.json { render_validation_errors(@workspace) }
      end
    end
  end

  def update
    if @workspace.update(workspace_params)
      track_event("workspace.update", resource: @workspace)
      respond_to do |format|
        format.html { redirect_to @workspace, notice: t(".updated") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = t(".errors")
          render :edit, status: :unprocessable_entity
        end
        format.json { render_validation_errors(@workspace) }
      end
    end
  end

  def destroy
    track_event("workspace.destroy", resource: @workspace)
    @workspace.soft_delete

    respond_to do |format|
      format.html { redirect_to workspaces_url, notice: t(".destroyed"), status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def workspace_params
    params.require(:workspace).permit(:name, :description)
  end
end
