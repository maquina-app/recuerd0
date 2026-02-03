class Workspaces::ArchivesController < ApplicationController
  include WorkspaceScoped

  # GET /workspaces/archived
  def index
    @pagy, @workspaces = pagy(Current.user.workspaces.archived_ordered)
  end

  # GET /workspaces/archived/:id
  def show
    unless @workspace.archived?
      redirect_to workspaces_path, alert: "This workspace is not archived."
      return
    end

    @pagy, @memories = pagy(@workspace.memories.includes(:content, :pins).order(created_at: :desc), items: 10)
    @pinned_memories, @regular_memories = @memories.partition { |m| m.pinned_by?(Current.user) }
    render "workspaces/show"
  end

  # POST /workspaces/:id/archive
  def create
    if @workspace.archive
      redirect_to workspaces_path, notice: "Workspace was successfully archived."
    else
      redirect_to workspaces_path, alert: "Failed to archive workspace."
    end
  end

  # DELETE /workspaces/:id/archive
  def destroy
    if @workspace.unarchive
      redirect_to workspaces_path, notice: "Workspace was successfully unarchived."
    else
      redirect_to workspaces_path, alert: "Failed to unarchive workspace."
    end
  end
end
