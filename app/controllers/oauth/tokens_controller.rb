# Issues access and refresh tokens after a valid code exchange or refresh grant.
# Validates PKCE S256 before issuing any token. Tokens are persisted as
# AccessToken records (digests only); raw values are returned once.
class Oauth::TokensController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  # Per-IP. Token exchange + hourly refresh for many users can share an egress IP
  # (browser/agent infra), so this is generous; codes/refresh tokens are
  # high-entropy and single-use, so a tight limit adds little brute-force value.
  rate_limit to: 30, within: 1.minute,
    with: -> { render json: {error: "rate_limit_exceeded", error_description: "Too many token requests"}, status: :too_many_requests }

  # POST /oauth/token
  def create
    case params[:grant_type]
    when "authorization_code" then exchange_code
    when "refresh_token" then refresh
    else
      render json: {error: "unsupported_grant_type"}, status: :bad_request
    end
  end

  private

  def exchange_code
    client = OauthClient.find_by(client_id: params[:client_id])
    return render_error("invalid_client", status: :unauthorized) unless client

    auth_code = client.oauth_authorization_codes.active.find_by(code: params[:code], redirect_uri: params[:redirect_uri])
    return render_error("invalid_grant", "Code not found or expired") unless auth_code
    return render_error("invalid_grant", "PKCE verification failed") unless auth_code.pkce_valid?(params[:code_verifier])

    token = auth_code.user.access_tokens.build(
      oauth_client: client,
      permission: AccessToken.permission_for_scope(auth_code.scope),
      oauth_scope: auth_code.scope,
      description: client.client_name,
      expires_at: 1.hour.from_now
    )
    token.assign_refresh_token!
    token.save!
    auth_code.destroy

    render json: token_response(token)
  end

  def refresh
    token = AccessToken.find_by_refresh_token(params[:refresh_token])
    return render_error("invalid_grant", "Refresh token invalid or expired") unless token

    token.assign_access_token!
    token.assign_refresh_token!
    token.expires_at = 1.hour.from_now
    token.save!

    render json: token_response(token)
  end

  def token_response(token)
    {
      access_token: token.raw_token,
      token_type: "Bearer",
      expires_in: 3600,
      refresh_token: token.raw_refresh_token,
      scope: token.oauth_scope
    }
  end

  def render_error(error, description = nil, status: :bad_request)
    body = {error: error}
    body[:error_description] = description if description
    render json: body, status: status
  end
end
