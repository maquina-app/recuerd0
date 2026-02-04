class MemoriesController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace
  before_action :set_memory, only: %i[show edit update destroy]
  before_action :require_active_workspace, only: %i[new create edit update destroy]

  def preview
    @content = params[:content].to_s
    render layout: false
  end

  def show
    @all_versions = @memory.all_versions
  end

  def new
    @memory = @workspace.memories.build
  end

  def create
    @memory = Memory.create_with_content(@workspace, memory_params)

    if @memory.persisted?
      redirect_to [@workspace, @memory], notice: t(".created")
    else
      flash.now[:alert] = t(".errors")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    # Ensure content exists before editing
    @memory.content || @memory.create_content(body: "")
  end

  def update
    @memory.update_with_content(memory_params)

    if @memory.errors.empty?
      redirect_to [@workspace, @memory], notice: t(".updated")
    else
      flash.now[:alert] = t(".errors")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @memory.destroy
    redirect_to workspace_path(@workspace),
      notice: t(".destroyed"),
      status: :see_other
  end

  private

  def set_memory
    @memory = @workspace.memories.find(params[:id])
  end

  def require_active_workspace
    return if @workspace.active?

    redirect_to workspace_path(@workspace),
      alert: t("workspaces.inactive_workspace")
  end

  def memory_params
    params.require(:memory).permit(:title, :source, :content, tags: [])
  end
end
