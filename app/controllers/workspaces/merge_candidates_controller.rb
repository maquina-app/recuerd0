class Workspaces::MergeCandidatesController < ApplicationController
  include ObsoleteFilterable

  allow_token_authentication

  before_action :set_workspace
  before_action :ensure_not_deleted

  # GET /workspaces/:workspace_id/merge_candidates.json
  #
  # Read-only suggestions of likely-duplicate memories, clustered by shared tags
  # and title similarity. Mirrors the suggest_merge_candidates MCP tool. Merging
  # remains a human decision — this only proposes clusters.
  def show
    if params.key?(:min_score) && !requested_min_score&.between?(0, 1)
      return render_validation_error("min_score must be a number from 0 to 1")
    end

    finder = if params.key?(:min_score)
      WorkspaceMergeCandidates.new(@workspace, min_score: requested_min_score, include_obsolete: include_obsolete?)
    else
      WorkspaceMergeCandidates.new(@workspace, include_obsolete: include_obsolete?)
    end

    @clusters = finder.clusters
  end

  private

  def requested_min_score
    Float(params[:min_score], exception: false)
  end

  def set_workspace
    @workspace = Current.account.workspaces.find(params[:workspace_id])
  end

  def ensure_not_deleted
    render_not_found if @workspace.deleted?
  end
end
