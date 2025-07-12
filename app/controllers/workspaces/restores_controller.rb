class Workspaces::RestoresController < ApplicationController
  before_action :set_workspace

  # POST /workspaces/:id/restore
  def create
    if @workspace.restore
      redirect_to @workspace, notice: "Workspace was successfully restored."
    else
      redirect_to workspaces_path, alert: "Failed to restore workspace."
    end
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.with_deleted.find(params[:id])
  end
end
