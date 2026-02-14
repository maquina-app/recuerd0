class HomeController < ApplicationController
  allow_unauthenticated_access

  layout "marketing"

  def index
  end
end
