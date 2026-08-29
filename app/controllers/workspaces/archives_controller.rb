class Workspaces::ArchivesController < ApplicationController
  include WorkspaceScoped
  include WorkspaceViewMode

  before_action :set_workspace, except: [:index]
  before_action :require_full_access, only: %i[create destroy], if: :api_request?

  # GET /workspaces/archived
  def index
    @view_mode = resolve_workspace_view_mode
    @query = params[:q].to_s.strip.first(80).presence

    scope = Current.account.workspaces.archived_ordered
    @total = scope.count
    scope = scope.search(@query) if @query

    @pagy, @workspaces = pagy(scope)
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
        format.html { redirect_to workspaces_path, notice: t("workspaces/archives.create.created", name: @workspace.name) }
        format.json { render "workspaces/show", status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to workspaces_path, alert: t("workspaces/archives.create.error") }
        format.json { render_validation_errors(@workspace) }
      end
    end
  end

  # DELETE /workspaces/:id/archive
  def destroy
    if @workspace.unarchive
      track_event("workspace.unarchive", resource: @workspace)
      respond_to do |format|
        format.html { redirect_to workspaces_path, notice: t("workspaces/archives.destroy.destroyed", name: @workspace.name), status: :see_other }
        format.json { render "workspaces/show", status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to workspaces_path, alert: t("workspaces/archives.destroy.error"), status: :see_other }
        format.json { render_validation_errors(@workspace) }
      end
    end
  end
end
