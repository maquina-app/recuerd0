class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend
  include ApiHelpers
  include Analytics::Trackable

  helper_method :multi_tenant?

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, if: -> { !api_request? }

  # Skip CSRF verification only for Bearer-token requests. A session cookie is
  # never exempt: "looks like JSON" used to be enough, which left a same-site
  # subdomain one step away from forging browser writes.
  skip_forgery_protection if: -> { extract_bearer_token.present? }

  # Read-only tokens never write, on any endpoint and in any format. Lives here
  # rather than per controller so a new write action is covered by default.
  before_action :require_full_access

  # Rate limit API requests: 100 requests per minute per token/user/IP.
  # OAuth + MCP endpoints opt out (self_managed_rate_limit?) — their traffic
  # arrives from shared proxy/agent egress IPs, so they limit per-token/client
  # via their own rate_limit blocks instead of this per-IP one.
  rate_limit to: 100, within: 1.minute,
    if: -> { api_request? && !self_managed_rate_limit? },
    by: -> { current_access_token&.id || Current.user&.id || request.remote_ip },
    with: -> { render_rate_limited }

  after_action :set_api_cache_control, if: :api_request?
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

  private

  def set_api_cache_control
    expires_in 0, public: false
  end

  def handle_record_not_found
    if api_request?
      render_not_found
    else
      raise
    end
  end

  def require_full_access
    return if request.get? || request.head?
    return unless current_access_token&.read_only?

    render_forbidden
  end

  def multi_tenant?
    Rails.application.config.multi_tenant
  end

  def api_request?
    request.format.json? || request.accepts.any? { |type| type&.json? }
  end

  # OAuth and MCP controllers declare their own rate limits keyed by token/client,
  # so they skip the global per-IP API limit (their traffic shares egress IPs).
  def self_managed_rate_limit?
    controller_path.start_with?("oauth/") || controller_path == "mcp"
  end
end
