class Workspaces::RestoresController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace

  def create
    if @workspace.restore
      redirect_to @workspace, notice: t(".created")
    else
      redirect_to deleted_workspaces_path, alert: t(".error")
    end
  end
end
