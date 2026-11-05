class Workspaces::OwnershipsController < ApplicationController
  include WorkspaceScoped
  include OwnershipTransferring

  before_action :set_workspace
  before_action :ensure_not_deleted
  before_action :set_ownable

  private

  def set_ownable
    return redirect_to(deleted_workspaces_path, alert: t("ownership.restore_first"), status: :see_other) if @workspace.deleted?

    @ownable = @workspace
  end

  def ownership_return_path
    helpers.workspace_link_path(@workspace)
  end
end
