# Serves OAuth discovery documents required by RFC 9728 and RFC 8414 so MCP
# clients can locate the authorization server and the protected resource.
class Oauth::WellKnownController < ApplicationController
  allow_unauthenticated_access

  SCOPES = %w[memories:read memories:write workspaces:read].freeze

  # GET /.well-known/oauth-protected-resource (RFC 9728)
  def protected_resource
    render json: {
      resource: "#{request.base_url}/mcp",
      authorization_servers: [issuer],
      scopes_supported: SCOPES,
      bearer_methods_supported: ["header"]
    }
  end

  # GET /.well-known/oauth-authorization-server (RFC 8414)
  def authorization_server
    render json: {
      issuer: issuer,
      authorization_endpoint: "#{issuer}/oauth/authorize",
      token_endpoint: "#{issuer}/oauth/token",
      registration_endpoint: "#{issuer}/oauth/register",
      revocation_endpoint: "#{issuer}/oauth/revoke",
      response_types_supported: ["code"],
      grant_types_supported: %w[authorization_code refresh_token],
      code_challenge_methods_supported: ["S256"],
      token_endpoint_auth_methods_supported: ["none"],
      scopes_supported: SCOPES,
      client_id_metadata_document_supported: false
    }
  end

  private

  def issuer
    request.base_url
  end
end
