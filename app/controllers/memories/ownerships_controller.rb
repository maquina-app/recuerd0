class Memories::OwnershipsController < ApplicationController
  include WorkspaceScoped
  include OwnershipTransferring

  before_action :set_workspace
  before_action :ensure_not_deleted
  before_action :require_active_workspace
  before_action :set_ownable

  private

  def set_ownable
    @ownable = @workspace.memories.find(params[:memory_id]).root_memory
  end

  def ownership_return_path
    workspace_memory_path(@workspace, @ownable)
  end
end
