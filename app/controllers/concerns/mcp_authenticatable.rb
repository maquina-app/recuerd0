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
    return render_mcp_unauthorized("Invalid or expired token") unless @current_oauth_token

    @current_oauth_token.touch_last_used!
    @mcp_account = @current_oauth_token.user.account
  end

  def render_mcp_unauthorized(message)
    # RFC 9728: resource metadata lives at the resource-path-suffixed well-known URL.
    response.set_header("WWW-Authenticate",
      %(Bearer resource_metadata="#{request.base_url}/.well-known/oauth-protected-resource/mcp"))
    render json: jsonrpc_error(nil, -32_001, message), status: :unauthorized
  end
end
