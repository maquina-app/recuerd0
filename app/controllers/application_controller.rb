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

  before_action :reject_null_characters, if: -> { api_request? && !self_managed_rate_limit? }

  after_action :set_api_cache_control, if: :api_request?
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing
  rescue_from ActionDispatch::Http::Parameters::ParseError, with: :handle_malformed_body
  rescue_from ActionController::UnknownFormat, with: :handle_unknown_format
  rescue_from Pagy::VariableError, with: :handle_invalid_page

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

  # Also what a body of the wrong shape lands on: nothing, a JSON array, JSON
  # sent as text/plain, or a string where the object belongs.
  def handle_parameter_missing(error)
    raise error unless api_request?

    render_validation_error("Send a #{error.param} object with at least one field")
  end

  def handle_malformed_body(error)
    raise error unless api_request?

    render_bad_request("The request body is not valid JSON")
  end

  def handle_unknown_format(error)
    raise error unless api_request?

    render_not_acceptable
  end

  def handle_invalid_page(error)
    raise error unless api_request?

    render_validation_error("page must be a positive integer")
  end

  # SQLite treats NUL as the end of a string in LOWER, FTS and friends, so text
  # holding one would be stored and then misbehave everywhere it is read.
  def reject_null_characters
    render_validation_error("Text can't contain null characters") if null_character_in?(params.to_unsafe_h)
  end

  def null_character_in?(value)
    case value
    when String then value.include?("\u0000")
    when Hash then value.any? { |key, item| null_character_in?(key) || null_character_in?(item) }
    when Array then value.any? { |item| null_character_in?(item) }
    else false
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

  # The path is checked on its own because an unparseable body makes request.format
  # fall back to the Accept header, which would turn the error for a bad JSON
  # request into an HTML page.
  def api_request?
    request.path_parameters[:format].to_s == "json" || request.format.json? || request.accepts.any? { |type| type&.json? }
  end

  # OAuth and MCP controllers declare their own rate limits keyed by token/client,
  # so they skip the global per-IP API limit (their traffic shares egress IPs).
  def self_managed_rate_limit?
    controller_path.start_with?("oauth/") || controller_path == "mcp"
  end
end
