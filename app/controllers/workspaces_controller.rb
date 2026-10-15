class WorkspacesController < ApplicationController
  include WorkspaceScoped
  include WorkspaceViewMode

  allow_token_authentication

  before_action :set_workspace, only: %i[show edit update destroy]
  before_action :require_active_workspace, only: %i[edit update]

  def index
    @view_mode = resolve_workspace_view_mode
    @sort = params[:sort].presence_in(%w[name memories]) # nil => default "recent"
    @query = params[:q].to_s.strip.first(80).presence

    scope = Current.account.workspaces.active

    # The filter is server-side so it searches the whole account, not just the
    # page you happen to be on. @total is the unfiltered count, so the header
    # can say "3 of 21" rather than contradicting the list.
    @total = scope.count
    scope = scope.search(@query) if @query

    workspaces = scope
      .ordered_with_pins_first(Current.user, sort: @sort)
      .includes(:pins)
      .select(<<~SQL.squish)
        workspaces.*,
        (SELECT MAX(memories.created_at) FROM memories WHERE memories.workspace_id = workspaces.id) AS last_activity_at
      SQL

    @pagy, @workspaces = pagy(workspaces)
    @stale_after = Workspace.stale_threshold_for(Current.account)

    respond_to do |format|
      format.html
      format.json { set_pagination_headers(@pagy) }
    end
  end

  def show
    respond_to do |format|
      format.html do
        if @workspace.archived?
          redirect_to archived_workspace_path(@workspace)
          return
        elsif @workspace.deleted?
          redirect_to deleted_workspace_path(@workspace)
          return
        end

        track_event("workspace.view", resource: @workspace)
        # Staleness is account-relative, so the header chip agrees with the flag
        # the index showed on the row the visitor just clicked.
        @stale_after = Workspace.stale_threshold_for(Current.account)
        load_workspace_memories
      end
      # Keyed on the viewer too: the JSON renders per-user pin state outside
      # the record-keyed cache block, so a record-only validator would serve
      # one user the pin state cached for another.
      format.json { stale?(etag: [@workspace, Current.user]) }
    end
  end

  def new
    @workspace = Current.account.workspaces.build
  end

  def edit
  end

  def create
    @workspace = Current.account.workspaces.build(workspace_params)

    if @workspace.save
      track_event("workspace.create", resource: @workspace)
      respond_to do |format|
        format.html { redirect_to @workspace, notice: t(".created", name: @workspace.name) }
        format.json { render :show, status: :created }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = t(".errors")
          render :new, status: :unprocessable_entity
        end
        format.json { render_validation_errors(@workspace) }
      end
    end
  end

  def update
    if @workspace.update(workspace_params)
      track_event("workspace.update", resource: @workspace)
      respond_to do |format|
        format.html { redirect_to @workspace, notice: t(".updated", name: @workspace.name) }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = t(".errors")
          render :edit, status: :unprocessable_entity
        end
        format.json { render_validation_errors(@workspace) }
      end
    end
  end

  def destroy
    track_event("workspace.destroy", resource: @workspace)
    @workspace.soft_delete

    respond_to do |format|
      format.html { redirect_to workspaces_url, notice: t(".destroyed", name: @workspace.name, days: SoftDeletable::RETENTION_DAYS), status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  def workspace_params
    params.require(:workspace).permit(:name, :description)
  end
end
