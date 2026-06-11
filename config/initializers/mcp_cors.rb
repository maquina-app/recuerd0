# CORS for the remote MCP server and its OAuth 2.1 endpoints.
#
# Browser-based MCP clients (the MCP Inspector, and per the MCP spec's CORS
# recommendation) run OAuth discovery, dynamic client registration, and token
# exchange via fetch() from their own origin, so these endpoints must return
# permissive CORS headers and answer preflight (OPTIONS) requests.
#
# Auth here is via Bearer token / PKCE and never via cookies, so a wildcard
# origin without credentials is safe: browsers won't attach our session cookie
# to these cross-origin requests. The consent screen (/oauth/authorize) is a
# top-level navigation and is deliberately excluded.
class McpCors
  CORS_PATH = %r{\A/(mcp\z|oauth/(register|token|revoke)|\.well-known/)}

  HEADERS = {
    "access-control-allow-origin" => "*",
    "access-control-allow-methods" => "GET, POST, OPTIONS",
    "access-control-allow-headers" => "Authorization, Content-Type, Mcp-Session-Id, MCP-Protocol-Version",
    "access-control-expose-headers" => "WWW-Authenticate, Mcp-Session-Id",
    "access-control-max-age" => "86400"
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless env["PATH_INFO"].match?(CORS_PATH)
    return [204, HEADERS.dup, []] if env["REQUEST_METHOD"] == "OPTIONS"

    status, headers, body = @app.call(env)
    [status, headers.merge(HEADERS), body]
  end
end

Rails.application.config.middleware.insert_before 0, McpCors
