class Workspaces::ContextsController < ApplicationController
  before_action :set_workspace
  before_action :ensure_not_deleted

  # GET /workspaces/:workspace_id/context.json
  def show
    @limit = clamp_int(params[:limit], default: 10, min: 1, max: 50)
    @include_body = to_bool(params[:include_body], default: true)
    @max_body_chars = clamp_int(params[:max_body_chars], default: 500, min: 100, max: 5000)

    pinned_scope = Current.user.pinned_memories
      .where(workspace: @workspace)
      .includes(:content, :pins, :workspace)

    @total_pinned = pinned_scope.count
    @pinned_memories = pinned_scope.limit(@limit).to_a

    latest = [@workspace.updated_at, @pinned_memories.map(&:updated_at).compact.max].compact.max
    stale?(etag: [@workspace, @pinned_memories, @limit, @include_body, @max_body_chars], last_modified: latest)
  end

  private

  def set_workspace
    @workspace = Current.account.workspaces.find(params[:workspace_id])
  end

  def ensure_not_deleted
    render_not_found if @workspace.deleted?
  end

  def clamp_int(value, default:, min:, max:)
    n = begin
      Integer(value)
    rescue
      default
    end
    n.clamp(min, max)
  end

  def to_bool(value, default:)
    return default if value.nil?
    ActiveModel::Type::Boolean.new.cast(value)
  end
end
