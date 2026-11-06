# Authenticates MCP requests via OAuth Bearer tokens (AccessToken records).
# Sets @current_oauth_token and @mcp_account for downstream tool dispatch.
module McpAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :require_mcp_token
  end

  private

  def require_mcp_token
    raw = extract_bearer_token
    return render_mcp_unauthorized("Missing Authorization header") unless raw

    @current_oauth_token = AccessToken.find_by_token(raw)
    return render_mcp_failed_token unless @current_oauth_token

    # RFC 8707: an OAuth token is only good for the resource it was issued for.
    # Manual API tokens (no oauth_client) aren't OAuth tokens, carry no
    # audience, and keep working here as they do on the REST API.
    if @current_oauth_token.oauth_client && @current_oauth_token.audience != canonical_resource
      return render_mcp_failed_token
    end

    @mcp_account = @current_oauth_token.user.account
    return render_mcp_unauthorized("Invalid or expired token") if @mcp_account.deleted?

    @current_oauth_token.touch_last_used!
  end

  # The count is shared with REST (Authentication#failed_token_limit_reached?). A
  # request with no token isn't counted: that 401 is how a client discovers OAuth.
  def render_mcp_failed_token
    return render_mcp_unauthorized("Invalid or expired token") unless failed_token_limit_reached?

    response.set_header("Retry-After", Authentication::FAILED_TOKEN_WINDOW.to_i.to_s)
    render json: jsonrpc_error(nil, -32_000, "Rate limit exceeded"), status: :too_many_requests
  end

  def canonical_resource
    "#{request.base_url}/mcp"
  end

  # RFC 9728: resource metadata lives at the resource-path-suffixed well-known URL.
  def resource_metadata_url
    "#{request.base_url}/.well-known/oauth-protected-resource/mcp"
  end

  def render_mcp_unauthorized(message)
    response.set_header("WWW-Authenticate",
      %(Bearer scope="memories:read", resource_metadata="#{resource_metadata_url}"))
    render json: jsonrpc_error(nil, -32_001, message), status: :unauthorized
  end
end
