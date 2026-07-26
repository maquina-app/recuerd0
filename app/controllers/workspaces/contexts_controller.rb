class Workspaces::ContextsController < ApplicationController
  before_action :set_workspace
  before_action :ensure_not_deleted

  # GET /workspaces/:workspace_id/context.json
  def show
    @limit = clamp_int(params[:limit], default: 10, min: 1, max: 50)
    @include_body = to_bool(params[:include_body], default: true)
    @max_body_chars = clamp_int(params[:max_body_chars], default: 500, min: 100, max: 5000)

    result = Workspaces::ContextResolver.call(
      workspace: @workspace,
      user: Current.user,
      limit: @limit,
      category: params[:category]
    )
    @memories = result[:memories]
    @context_source = result[:source]
    @total_pinned = result[:total_pinned]

    memory_timestamps = @memories.flat_map do |memory|
      [memory.updated_at, memory.resolve_current_version.updated_at]
    end
    latest = [@workspace.updated_at, *memory_timestamps].compact.max
    stale?(
      etag: [
        @workspace,
        @memories,
        @context_source,
        @total_pinned,
        params[:category],
        @limit,
        @include_body,
        @max_body_chars
      ],
      last_modified: latest
    )
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
