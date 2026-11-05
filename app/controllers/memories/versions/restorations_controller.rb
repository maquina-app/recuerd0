# "Restore as new version": copies one specific version forward as the current one.
# Browser only. An API client that wants this reads the version and writes it back.
class Memories::Versions::RestorationsController < ApplicationController
  include WorkspaceScoped

  before_action :set_workspace
  before_action :ensure_not_deleted
  before_action :set_version
  before_action :require_active_workspace

  def create
    restored = @version.create_version!(
      change_note: t(".note", from: @version.version_label),
      created_by: Current.user
    )

    if restored.persisted?
      track_event("version.create", resource: restored)
      redirect_to workspace_memory_path(@workspace, @version.stable_id),
        notice: t(".restored", from: @version.version_label, version: restored.version_label)
    else
      redirect_to workspace_memory_path(@workspace, @version.stable_id), alert: t(".failed")
    end
  end

  private

  def set_version
    @version = @workspace.memories.find(params[:memory_id]).all_versions.find(params[:version_id])
  end
end
