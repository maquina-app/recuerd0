class WorkspacesController < ApplicationController
  before_action :set_workspace, only: %i[show edit update destroy]

  # GET /workspaces
  def index
    @workspaces = Current.user.workspaces.active.ordered

    # Load soft deleted and archived workspaces for display
    @deleted_workspaces = Current.user.workspaces.only_deleted.ordered
    @archived_workspaces = Current.user.workspaces.archived.ordered
  end

  # GET /workspaces/1
  def show
    unless @workspace.active?
      redirect_to workspaces_path, alert: "This workspace is not accessible."
      return
    end

    @pagy, @memories = pagy(@workspace.memories.includes(:content).order(created_at: :desc), items: 10)
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
