module WorkspaceScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_workspace, except: [:index]
  end

  private

  def set_workspace
    @workspace = Current.user.workspaces.find(params[:id])
  end
end
