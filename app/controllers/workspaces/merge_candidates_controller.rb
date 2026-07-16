class Workspaces::MergeCandidatesController < ApplicationController
  before_action :set_workspace
  before_action :ensure_not_deleted

  # GET /workspaces/:workspace_id/merge_candidates.json
  #
  # Read-only suggestions of likely-duplicate memories, clustered by shared tags
  # and title similarity. Mirrors the suggest_merge_candidates MCP tool. Merging
  # remains a human decision — this only proposes clusters.
  def show
    finder = if params[:min_score].present?
      WorkspaceMergeCandidates.new(@workspace, min_score: params[:min_score].to_f)
    else
      WorkspaceMergeCandidates.new(@workspace)
    end

    @clusters = finder.clusters
  end

  private

  def set_workspace
    @workspace = Current.account.workspaces.find(params[:workspace_id])
  end

  def ensure_not_deleted
    render_not_found if @workspace.deleted?
  end
end
