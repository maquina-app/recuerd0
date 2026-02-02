class MemoriesController < ApplicationController
  before_action :set_workspace
  before_action :set_memory, only: %i[show edit update destroy]

  def show
    unless @workspace.active?
      redirect_to workspace_path(@workspace),
        alert: "Cannot view memories in #{@workspace.deleted? ? "deleted" : "archived"} workspace."
      return
    end

    @all_versions = @memory.all_versions.includes(:content)
    @current_version = @memory
  end

  def new
    unless @workspace.active?
      redirect_to workspace_path(@workspace),
        alert: "Cannot create memories in #{@workspace.deleted? ? "deleted" : "archived"} workspace."
      return
    end

    @memory = @workspace.memories.build
  end

  def create
    unless @workspace.active?
      redirect_to workspace_path(@workspace),
        alert: "Cannot create memories in #{@workspace.deleted? ? "deleted" : "archived"} workspace."
      return
    end

    @memory = CreateMemory.call(@workspace, memory_params)

    if @memory.persisted?
      redirect_to [@workspace, @memory], notice: "Memory was successfully created."
    else
      flash.now[:alert] = "Please review the errors below."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    unless @workspace.active?
      redirect_to [@workspace, @memory],
        alert: "Cannot edit memories in #{@workspace.deleted? ? "deleted" : "archived"} workspace."
      return
    end

    # Ensure content exists before editing
    @memory.content || @memory.create_content(body: "")
  end

  def update
    unless @workspace.active?
      redirect_to [@workspace, @memory],
        alert: "Cannot update memories in #{@workspace.deleted? ? "deleted" : "archived"} workspace."
      return
    end

    @memory = UpdateMemory.call(@memory, memory_params)

    if @memory.errors.empty?
      redirect_to [@workspace, @memory], notice: "Memory was successfully updated."
    else
      flash.now[:alert] = "Please review the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @workspace.active?
      redirect_to workspace_path(@workspace),
        alert: "Cannot delete memories in #{@workspace.deleted? ? "deleted" : "archived"} workspace."
      return
    end

    @memory.destroy
    redirect_to workspace_path(@workspace),
      notice: "Memory was successfully deleted.",
      status: :see_other
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.with_deleted.find(params[:workspace_id])
  end

  def set_memory
    @memory = @workspace.memories.find(params[:id])
  end

  def memory_params
    params.require(:memory).permit(:title, :source, :content, tags: [])
  end
end
