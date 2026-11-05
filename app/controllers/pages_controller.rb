class PagesController < ApplicationController
  layout "marketing"

  allow_unauthenticated_access
  # Public pages, but a signed-in visitor still needs their way back to the app.
  before_action :resume_session

  def terms
  end

  def privacy
  end

  def start
  end

  def api_docs
  end

  def cli
  end

  def agents
  end

  def mcp
  end

  def pricing
  end

  def license
  end
end
