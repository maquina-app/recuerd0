class Workspaces::ArchivesController < ApplicationController
  before_action :set_workspace

  # POST /workspaces/:id/archive
  def create
    if @workspace.archive
      redirect_to workspaces_path, notice: "Workspace was successfully archived."
    else
      redirect_to workspaces_path, alert: "Failed to archive workspace."
    end
  end

  # DELETE /workspaces/:id/archive
  def destroy
    if @workspace.unarchive
      redirect_to workspaces_path, notice: "Workspace was successfully unarchived."
    else
      redirect_to workspaces_path, alert: "Failed to unarchive workspace."
    end
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.with_deleted.find(params[:id])
  end
end
