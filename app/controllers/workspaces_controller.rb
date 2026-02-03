class WorkspacesController < ApplicationController
  before_action :set_workspace, only: %i[show edit update destroy]
  before_action :require_active_workspace, only: %i[edit update]

  def index
    workspaces = Current.user.workspaces
      .active
      .ordered_with_pins_first(Current.user)
      .includes(:pins)

    @pagy, @workspaces = pagy(workspaces)
  end

  def show
    if @workspace.archived?
      redirect_to archived_workspace_path(@workspace)
      return
    elsif @workspace.deleted?
      redirect_to deleted_workspace_path(@workspace)
      return
    end

    memories_scope = @workspace.memories
      .latest_versions
      .includes(:content, :child_versions, :pins)
      .order(updated_at: :desc)

    @pagy, @memories = pagy(memories_scope, items: 10)
    @pinned_memories, @regular_memories = @memories.partition { |m| m.pinned_by?(Current.user) }
  end

  def new
    @workspace = Current.user.workspaces.build
  end

  def edit
  end

  def create
    @workspace = Current.user.workspaces.build(workspace_params)

    if @workspace.save
      redirect_to @workspace, notice: t(".created")
    else
      flash.now[:alert] = t(".errors")
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @workspace.update(workspace_params)
      redirect_to @workspace, notice: t(".updated")
    else
      flash.now[:alert] = t(".errors")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @workspace.soft_delete
    redirect_to workspaces_url, notice: t(".destroyed"), status: :see_other
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.with_deleted.find(params[:id])
  end

  def require_active_workspace
    return if @workspace.active?

    redirect_to workspaces_path, alert: t("workspaces.inactive_workspace")
  end

  def workspace_params
    params.require(:workspace).permit(:name, :description)
  end
end
