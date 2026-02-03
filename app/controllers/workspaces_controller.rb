class WorkspacesController < ApplicationController
  before_action :set_workspace, only: %i[show edit update destroy]

  # GET /workspaces
  def index
    workspaces = Current.user.workspaces
      .active
      .ordered_with_pins_first(Current.user)
      .includes(:memories)

    @pagy, @workspaces = pagy(workspaces)
  end

  # GET /workspaces/1
  def show
    if @workspace.archived?
      redirect_to archived_workspace_path(@workspace)
      return
    elsif @workspace.deleted?
      redirect_to deleted_workspace_path(@workspace)
      return
    end

    # Load only latest versions with eager loading for performance
    memories_scope = @workspace.memories
      .latest_versions
      .includes(:content, :child_versions)
      .order(updated_at: :desc)

    @pagy, @memories = pagy(memories_scope, items: 10)
  end

  # GET /workspaces/new
  def new
    @workspace = Current.user.workspaces.build
  end

  # GET /workspaces/1/edit
  def edit
    unless @workspace.active?
      redirect_to workspaces_path, alert: "This workspace cannot be edited."
      nil
    end
  end

  # POST /workspaces
  def create
    @workspace = Current.user.workspaces.build(workspace_params)

    if @workspace.save
      redirect_to @workspace, notice: "Workspace was successfully created."
    else
      flash.now[:alert] = "Please review the errors below."
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /workspaces/1
  def update
    unless @workspace.active?
      redirect_to workspaces_path, alert: "This workspace cannot be updated."
      return
    end

    if @workspace.update(workspace_params)
      redirect_to @workspace, notice: "Workspace was successfully updated."
    else
      flash.now[:alert] = "Please review the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /workspaces/1
  def destroy
    @workspace.soft_delete
    redirect_to workspaces_url, notice: "Workspace was successfully deleted.", status: :see_other
  end

  private

  def set_workspace
    # Use with_deleted to find soft deleted workspaces as well
    @workspace = Current.user.workspaces.with_deleted.find(params[:id])
  end

  def workspace_params
    params.require(:workspace).permit(:name, :description)
  end
end
