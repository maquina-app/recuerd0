class PagesController < ApplicationController
  layout "marketing"

  allow_unauthenticated_access

  def terms
  end

  def privacy
  end

  def api_docs
  end
end
