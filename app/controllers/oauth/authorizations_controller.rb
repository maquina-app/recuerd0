# Renders and processes the user consent screen. The user must be signed in to
# Recuerd0 to approve; unauthenticated visitors are bounced to login and
# returned here automatically (Authentication#request_authentication).
class Oauth::AuthorizationsController < ApplicationController
  layout "security"

  # GET /oauth/authorize
  def new
    @client = find_client or return
    @authorization = authorization_params

    unless @client.redirect_uri_allowed?(@authorization[:redirect_uri])
      render plain: "Invalid redirect_uri", status: :bad_request
      return
    end

    if @authorization[:code_challenge_method] != "S256" || @authorization[:code_challenge].blank?
      redirect_error(@authorization[:redirect_uri], "invalid_request", "PKCE S256 code_challenge required")
    end
  end

  # POST /oauth/authorize
  def create
    @client = find_client or return

    unless @client.redirect_uri_allowed?(params[:redirect_uri])
      render plain: "Invalid redirect_uri", status: :bad_request
      return
    end

    if params[:approved] != "true"
      redirect_error(params[:redirect_uri], "access_denied", "User denied access")
      return
    end

    code = @client.oauth_authorization_codes.create!(
      user: Current.user,
      code: SecureRandom.urlsafe_base64(32),
      code_challenge: params[:code_challenge],
      code_challenge_method: "S256",
      redirect_uri: params[:redirect_uri],
      scope: params[:scope].presence || @client.scope,
      expires_at: 10.minutes.from_now
    )

    redirect_to callback_url(params[:redirect_uri], code: code.code, state: params[:state]), allow_other_host: true
  end

  private

  def find_client
    client = OauthClient.find_by(client_id: params[:client_id])
    render plain: "Unknown client", status: :bad_request unless client
    client
  end

  def authorization_params
    params.permit(:response_type, :redirect_uri, :scope, :state, :code_challenge, :code_challenge_method)
  end

  def redirect_error(uri, error, description)
    redirect_to callback_url(uri, error: error, error_description: description), allow_other_host: true
  end

  def callback_url(uri, query)
    separator = uri.include?("?") ? "&" : "?"
    "#{uri}#{separator}#{query.compact.to_query}"
  end
end
