class Workspaces::ArchivesController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace, except: [:index]

  # GET /workspaces/archived
  def index
    @pagy, @workspaces = pagy(Current.account.workspaces.archived_ordered)

    fresh_when_private(
      etag: collection_cache_key(
        Current.account.workspaces.archived,
        @pagy
      ),
      last_modified: Current.account.workspaces.archived.maximum(:updated_at)
    )
  end

  # GET /workspaces/archived/:id
  def show
    unless @workspace.archived?
      redirect_to workspaces_path, alert: t("workspaces/archives.not_archived")
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
