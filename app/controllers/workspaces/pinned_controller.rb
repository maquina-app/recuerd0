class Workspaces::PinnedController < ApplicationController
  # GET /workspaces/pinned
  def index
    @pagy, @workspaces = pagy(Current.user.pinned_workspaces)
  end
end
