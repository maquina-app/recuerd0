class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend
  include ApiHelpers
  include Analytics::Trackable

  helper_method :multi_tenant?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, if: -> { !api_request? }

  # Skip CSRF verification for API requests (authenticated via Bearer token)
  skip_forgery_protection if: -> { api_request? }

  # Rate limit API requests: 100 requests per minute per token/user/IP
  rate_limit to: 100, within: 1.minute,
    if: -> { api_request? },
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

  def require_full_access
    return true unless current_access_token
    return true if current_access_token.full_access?

    render_forbidden
    false
  end

  def multi_tenant?
    Rails.application.config.multi_tenant
  end

  def api_request?
    request.format.json? || request.accepts.any? { |type| type.json? }
  end
end
