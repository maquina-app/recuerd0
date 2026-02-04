class Workspaces::ArchivesController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace, except: [:index]

  # GET /workspaces/archived
  def index
    @pagy, @workspaces = pagy(Current.user.workspaces.archived_ordered)
  end

  # GET /workspaces/archived/:id
  def show
    unless @workspace.archived?
      redirect_to workspaces_path, alert: t("workspaces/archives.not_archived")
      return
    end

    load_workspace_memories
    render "workspaces/show"
  end

  # POST /workspaces/:id/archive
  def create
    if @workspace.archive
      redirect_to workspaces_path, notice: t(".created")
    else
      redirect_to workspaces_path, alert: t(".error")
    end
  end

  # DELETE /workspaces/:id/archive
  def destroy
    if @workspace.unarchive
      redirect_to workspaces_path, notice: t(".destroyed")
    else
      redirect_to workspaces_path, alert: t(".error")
    end
  end
end
