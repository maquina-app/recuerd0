class Workspaces::DeletedController < ApplicationController
  include WorkspaceScoped
  include WorkspaceViewMode

  before_action :set_workspace, except: [:index]

  # GET /workspaces/deleted
  def index
    @view_mode = resolve_workspace_view_mode
    @query = params[:q].to_s.strip.first(80).presence

    scope = Current.account.workspaces.deleted_ordered
    @total = scope.count
    scope = scope.search(@query) if @query

    @pagy, @workspaces = pagy(scope)
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
    # Analytics after the fact, not before: this used to record a permanent
    # destruction that then raised InvalidForeignKey and destroyed nothing.
    name = @workspace.name
    @workspace.destroy!
    track_event("workspace.permanent_destroy", metadata: {workspace_name: name})
    redirect_to deleted_workspaces_path, notice: t("workspaces/deleted.destroy.destroyed", name: name), status: :see_other
  end
end
