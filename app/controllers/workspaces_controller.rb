class WorkspacesController < ApplicationController
  before_action :set_workspace, only: %i[show edit update destroy]

  # GET /workspaces
  def index
    @workspaces = Current.user.workspaces.ordered
    @workspaces = @workspaces.search(params[:search]) if params[:search].present?
  end

  # GET /workspaces/1
  def show
    @pagy, @memories = pagy(@workspace.memories.includes(:content).order(created_at: :desc), items: 10)
  end

  # GET /workspaces/new
  def new
    @workspace = Current.user.workspaces.build
  end

  # GET /workspaces/1/edit
  def edit
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
    if @workspace.update(workspace_params)
      redirect_to @workspace, notice: "Workspace was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /workspaces/1
  def destroy
    @workspace.destroy!
    redirect_to workspaces_url, notice: "Workspace was successfully deleted.", status: :see_other
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.find(params[:id])
  end

  def workspace_params
    params.require(:workspace).permit(:name, :description)
  end
end
