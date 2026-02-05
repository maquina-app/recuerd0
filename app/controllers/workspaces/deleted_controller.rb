class Workspaces::DeletedController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace, except: [:index]

  # GET /workspaces/deleted
  def index
    @pagy, @workspaces = pagy(Current.account.workspaces.deleted_ordered)

    fresh_when_private(
      etag: collection_cache_key(
        Current.account.workspaces.deleted,
        @pagy
      ),
      last_modified: Current.account.workspaces.deleted.maximum(:updated_at)
    )
  end

  # GET /workspaces/deleted/:id
  def show
    unless @workspace.deleted?
      redirect_to workspaces_path, alert: t("workspaces/deleted.not_deleted")
      return
    end

    load_workspace_memories

    fresh_when_private(
      etag: collection_cache_key(
        @workspace.memories,
        @pagy,
        @workspace.updated_at
      ),
      last_modified: @workspace.updated_at
    )

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
