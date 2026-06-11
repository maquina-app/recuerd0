# Implements RFC 7591 Dynamic Client Registration. Claude calls this on first
# connection to self-register as a public (PKCE-only) client.
# Rate-limited: legitimate clients register once and cache their client_id.
class Oauth::RegistrationsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  # DCR happens once per client install (clients cache their client_id), but many
  # first-time users can register through shared egress at once. Per-IP.
  rate_limit to: 15, within: 1.minute,
    with: -> { render json: {error: "rate_limit_exceeded", error_description: "Too many registration attempts"}, status: :too_many_requests }

  # POST /oauth/register
  def create
    client = OauthClient.new(
      client_name: params[:client_name].presence || "MCP Client",
      redirect_uris: JSON.generate(Array(params[:redirect_uris])),
      grant_types: "authorization_code",
      token_endpoint_auth_method: "none",
      scope: "memories:read memories:write workspaces:read"
    )

    unless client.save
      render json: {error: "invalid_client_metadata", error_description: client.errors.full_messages.join(", ")}, status: :bad_request
      return
    end

    render json: {
      client_id: client.client_id,
      client_name: client.client_name,
      redirect_uris: client.redirect_uri_list,
      grant_types: ["authorization_code"],
      token_endpoint_auth_method: "none",
      scope: client.scope,
      client_id_issued_at: client.registered_at.to_i
    }, status: :created
  end
end
