class PagesController < ApplicationController
  layout "security"

  allow_unauthenticated_access

  def terms
  end

  def privacy
  end
end
