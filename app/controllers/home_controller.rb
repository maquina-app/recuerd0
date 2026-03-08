class HomeController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_authenticated_user

  layout "marketing"

  def index
  end
end
