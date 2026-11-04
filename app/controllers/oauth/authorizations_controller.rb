# Renders and processes the user consent screen. The user must be signed in to
# Recuerd0 to approve; unauthenticated visitors are bounced to login and
# returned here automatically (Authentication#request_authentication).
#
# Every protocol guard runs on both the GET and the POST, so a forged consent
# submission can't skip PKCE, change the response type or widen the scope.
class Oauth::AuthorizationsController < ApplicationController
  layout "security"

  before_action :set_client
  before_action :validate_redirect_uri
  before_action :validate_response_type
  before_action :validate_pkce
  before_action :validate_resource

  # GET /oauth/authorize
  def new
    @authorization = authorization_params
    @granted_scope = granted_scope
  end

  # POST /oauth/authorize
  def create
    if params[:approved] != "true"
      redirect_error("access_denied", "User denied access")
      return
    end

    code = @client.oauth_authorization_codes.create!(
      user: Current.user,
      code: SecureRandom.urlsafe_base64(32),
      code_challenge: params[:code_challenge],
      code_challenge_method: "S256",
      redirect_uri: params[:redirect_uri],
      scope: granted_scope,
      resource: canonical_resource,
      expires_at: 10.minutes.from_now
    )

    redirect_to callback_url(code: code.code), allow_other_host: true
  end

  private

  def set_client
    @client = OauthClient.find_by(client_id: params[:client_id])
    render plain: "Unknown client", status: :bad_request unless @client
  end

  def validate_redirect_uri
    render plain: "Invalid redirect_uri", status: :bad_request unless @client.redirect_uri_allowed?(params[:redirect_uri])
  end

  def validate_response_type
    redirect_error("unsupported_response_type", "response_type must be code") unless params[:response_type] == "code"
  end

  def validate_pkce
    if params[:code_challenge_method] != "S256" || params[:code_challenge].blank?
      redirect_error("invalid_request", "PKCE S256 code_challenge required")
    end
  end

  # RFC 8707: the only resource this server issues tokens for is its /mcp.
  def validate_resource
    if params[:resource].present? && params[:resource] != canonical_resource
      redirect_error("invalid_target", "resource must be #{canonical_resource}")
    end
  end

  def canonical_resource
    "#{request.base_url}/mcp"
  end

  # The requested scope, narrowed to what the server supports and what the
  # client registered for, so a tampered request can't widen it.
  def granted_scope
    (params[:scope].to_s.split & OauthClient::SCOPES & @client.scope.to_s.split).join(" ").presence || @client.scope
  end

  def authorization_params
    params.permit(:response_type, :redirect_uri, :state, :code_challenge, :code_challenge_method, :resource)
  end

  def redirect_error(error, description)
    redirect_to callback_url(error: error, error_description: description), allow_other_host: true
  end

  # Every callback carries state (when present) and iss (RFC 9207).
  def callback_url(query)
    uri = params[:redirect_uri]
    separator = uri.include?("?") ? "&" : "?"
    "#{uri}#{separator}#{query.merge(state: params[:state].presence, iss: request.base_url).compact.to_query}"
  end
end
