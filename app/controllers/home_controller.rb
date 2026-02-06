class HomeController < ApplicationController
  allow_unauthenticated_access

  layout :resolve_layout

  def index
  end

  private

  def resolve_layout
    authenticated? ? "application" : "marketing"
  end
end
