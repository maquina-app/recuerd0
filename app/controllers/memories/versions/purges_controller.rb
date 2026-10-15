class Memories::Versions::PurgesController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace
  before_action :ensure_not_deleted
  before_action :set_memory
  before_action :require_active_workspace
  before_action :require_history

  def new
    load_preview(requested_keep || 1)
  end

  def create
    keep = requested_keep

    if params[:current_version_id].to_s != @root.current_version.id.to_s
      @stale = true
      load_preview(keep || 1)
      render :new, status: :unprocessable_entity
    elsif keep.nil?
      @keep_error = t("memories.versions.purges.keep_invalid", max: @versions.size - 1)
      load_preview(1)
      @keep_input = params[:keep]
      render :new, status: :unprocessable_entity
    else
      deleted = @root.purge_versions!(keep:)
      track_event("version.purge", resource: @root, metadata: {kept: keep, deleted:})

      redirect_to workspace_memory_versions_path(@workspace, @root),
        notice: t(".purged", count: deleted, range: helpers.version_range_label(@root.all_versions))
    end
  end

  private

  def set_memory
    @memory = @workspace.memories.find(params[:memory_id])
    @root = @memory.root_memory
    @versions = @root.all_versions.to_a
  end

  def require_active_workspace
    return if @workspace.active?

    redirect_to [@workspace, @memory], alert: t("memories.versions.read_only")
  end

  def require_history
    return if @versions.size > 1

    redirect_to [@workspace, @memory], alert: t("memories.versions.purges.nothing_to_purge")
  end

  # nil unless it is an integer that leaves at least one version to delete.
  def requested_keep
    keep = Integer(params[:keep].to_s, 10, exception: false)
    keep if keep&.between?(1, @versions.size - 1)
  end

  def load_preview(keep)
    @keep = @keep_input = keep
    @kept = @versions.last(keep)
    @deleted = @versions.first(@versions.size - keep)

    moved_ids = Memory.rows_removed_by_purge(@versions, keep:)
    @moved_pins = Pin.where(pinnable_type: "Memory", pinnable_id: moved_ids).count
    @moved_links = MemoryLink.where(from_memory_id: moved_ids).or(MemoryLink.where(to_memory_id: moved_ids)).count
  end
end
