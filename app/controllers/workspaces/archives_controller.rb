class Workspaces::ArchivesController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace, except: [:index]
  before_action :require_full_access, only: %i[create destroy], if: :api_request?

  # GET /workspaces/archived
  def index
    @pagy, @workspaces = pagy(Current.account.workspaces.archived_ordered)
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
      track_event("workspace.archive", resource: @workspace)
      respond_to do |format|
        format.html { redirect_to workspaces_path, notice: t(".created") }
        format.json { render "workspaces/show", status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to workspaces_path, alert: t(".error") }
        format.json { render_validation_errors(@workspace) }
      end
    end
  end

  # DELETE /workspaces/:id/archive
  def destroy
    if @workspace.unarchive
      track_event("workspace.unarchive", resource: @workspace)
      respond_to do |format|
        format.html { redirect_to workspaces_path, notice: t(".destroyed") }
        format.json { render "workspaces/show", status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to workspaces_path, alert: t(".error") }
        format.json { render_validation_errors(@workspace) }
      end
    end
  end
end
