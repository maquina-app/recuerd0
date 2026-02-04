class Workspaces::DeletedController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace, except: [:index]

  # GET /workspaces/deleted
  def index
    @pagy, @workspaces = pagy(Current.user.workspaces.deleted_ordered)
  end

  # GET /workspaces/deleted/:id
  def show
    unless @workspace.deleted?
      redirect_to workspaces_path, alert: t("workspaces/deleted.not_deleted")
      return
    end

    load_workspace_memories
    render "workspaces/show"
  end

  # DELETE /workspaces/deleted/:id
  def destroy
    if @workspace.destroy!
      redirect_to deleted_workspaces_path, notice: t(".destroyed")
    else
      redirect_to deleted_workspaces_path, alert: t(".error")
    end
  end
end
