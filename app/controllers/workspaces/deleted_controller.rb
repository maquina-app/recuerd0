class Workspaces::DeletedController < ApplicationController
  include WorkspaceScoped

  # GET /workspaces/deleted
  def index
    @pagy, @workspaces = pagy(Current.user.workspaces.deleted_ordered)
  end

  # GET /workspaces/deleted/:id
  def show
    unless @workspace.deleted?
      redirect_to workspaces_path, alert: "This workspace is not deleted."
      return
    end

    @pagy, @memories = pagy(@workspace.memories.includes(:content).order(created_at: :desc), items: 10)
    render "workspaces/show"
  end

  # POST /workspaces/deleted/:id/restore
  def restore
    if @workspace.restore
      redirect_to @workspace, notice: "Workspace was successfully restored."
    else
      redirect_to deleted_workspaces_path, alert: "Failed to restore workspace."
    end
  end

  # DELETE /workspaces/deleted/:id
  def destroy
    if @workspace.destroy!
      redirect_to deleted_workspaces_path, notice: "Workspace was permanently deleted."
    else
      redirect_to deleted_workspaces_path, alert: "Failed to permanently delete workspace."
    end
  end
end
