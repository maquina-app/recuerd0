class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend
  include HttpCacheable
  include ApiHelpers

  before_action :load_ui_cookies

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, if: -> { !request.format.json? }

  # Rate limit API requests: 100 requests per minute per token/user/IP
  rate_limit to: 100, within: 1.minute,
    if: -> { request.format.json? },
    by: -> { current_access_token&.id || Current.user&.id || request.remote_ip },
    with: -> { render_rate_limited }

  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

  private

  def handle_record_not_found
    if api_request?
      render_not_found
    else
      raise
    end
  end

  def load_ui_cookies
    @sidebar_open = cookies["recuerd0_sidebar_state"] == "true"
  end

  def require_full_access
    return true unless current_access_token
    return true if current_access_token.full_access?

    render json: {
      error: {code: "FORBIDDEN", message: "Insufficient permissions", status: 403}
    }, status: :forbidden
    false
  end

  def api_request?
    request.format.json?
  end
end
