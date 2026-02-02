module WorkspaceScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_workspace, except: [:index]
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.with_deleted.find(params[:id])
  end
end
