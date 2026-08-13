class Workspaces::RestoresController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace

  def create
    if @workspace.restore
      redirect_to @workspace, notice: t("workspaces/restores.create.created")
    else
      redirect_to deleted_workspaces_path, alert: t("workspaces/restores.create.error")
    end
  end
end
