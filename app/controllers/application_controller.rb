class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend

  before_action :load_ui_cookies

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def load_ui_cookies
    @sidebar_open = cookies["recuerd0_sidebar_state"] == "true"

    # Load collapsible states
    @collapsible_states = begin
      JSON.parse(cookies["recuerd0_collapsible_states"] || "{}")
    rescue JSON::ParserError
      {}
    end
  end
end
