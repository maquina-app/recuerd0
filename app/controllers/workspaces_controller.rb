class WorkspacesController < ApplicationController
  def index
    @workspaces = Current.user.workspaces
  end
end
