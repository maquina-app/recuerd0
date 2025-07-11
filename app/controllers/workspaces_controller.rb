class WorkspacesController < ApplicationController
  before_action :set_workspace, only: %i[show edit update destroy]

  def index
    @workspaces = Current.user.workspaces.ordered
    @workspaces = @workspaces.search(params[:search]) if params[:search].present?
  end

  def show
    @pagy, @memories = pagy(@workspace.memories.includes(:content).order(created_at: :desc), items: 10)
  end

  def new
    @workspace = Current.user.workspaces.build
  end

  def create
    @workspace = Current.user.workspaces.build(workspace_params)

    if @workspace.save
      redirect_to @workspace, notice: "Workspace was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @workspace.update(workspace_params)
      redirect_to @workspace, notice: "Workspace was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workspace.destroy
    redirect_to workspaces_url, notice: "Workspace was successfully deleted."
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to workspaces_url, alert: "Workspace not found."
  end

  def workspace_params
    params.require(:workspace).permit(:name, :description)
  end
end
