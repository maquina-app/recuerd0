class MemoriesController < ApplicationController
  before_action :set_workspace
  before_action :set_memory, only: %i[show edit update destroy]
  before_action :require_active_workspace, only: %i[new create edit update destroy]

  def show
    @all_versions = @memory.all_versions.includes(:content)
    @current_version = @memory
  end

  def new
    @memory = @workspace.memories.build
  end

  def create
    @memory = CreateMemory.call(@workspace, memory_params)

    if @memory.persisted?
      redirect_to [@workspace, @memory], notice: "Memory was successfully created."
    else
      flash.now[:alert] = "Please review the errors below."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Ensure content exists before editing
    @memory.content || @memory.create_content(body: "")
  end

  def update
    @memory = UpdateMemory.call(@memory, memory_params)

    if @memory.errors.empty?
      redirect_to [@workspace, @memory], notice: "Memory was successfully updated."
    else
      flash.now[:alert] = "Please review the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
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

  def require_active_workspace
    return if @workspace.active?

    redirect_to workspace_path(@workspace),
      alert: "This workspace is in read-only mode."
  end

  def memory_params
    params.require(:memory).permit(:title, :source, :content, tags: [])
  end
end
