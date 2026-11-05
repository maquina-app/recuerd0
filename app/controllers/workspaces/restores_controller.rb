class Workspaces::RestoresController < ApplicationController
  include WorkspaceScoped
  include OwnershipAuthorizable

  before_action :set_workspace
  before_action -> { require_manage_access(@workspace) }

  def create
    if @workspace.restore
      redirect_to @workspace, notice: t("workspaces/restores.create.created", name: @workspace.name)
    else
      redirect_to deleted_workspaces_path, alert: t("workspaces/restores.create.error")
    end
  end
end
