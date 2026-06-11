# JSON-RPC 2.0 endpoint implementing the MCP protocol over HTTP.
# Each request is authenticated via an OAuth Bearer token (McpAuthenticatable).
# Rate-limited per token/IP to bound tool-call abuse from a compromised token.
class McpController < ApplicationController
  include McpAuthenticatable

  allow_unauthenticated_access # McpAuthenticatable enforces the Bearer token instead
  skip_forgery_protection

  # Per-token (not per-IP): agent tool calls arrive from shared egress IPs, and
  # an active turn can burst several calls. ~2/sec sustained per connection.
  rate_limit to: 120, within: 1.minute,
    by: -> { @current_oauth_token&.id || request.remote_ip },
    with: -> { render json: jsonrpc_error(nil, -32_000, "Rate limit exceeded"), status: :too_many_requests }

  # Published MCP protocol revisions, newest first. We echo the client's
  # requested version when we support it, otherwise advertise our latest.
  SUPPORTED_PROTOCOL_VERSIONS = %w[2025-06-18 2025-03-26 2024-11-05].freeze
  LATEST_PROTOCOL_VERSION = SUPPORTED_PROTOCOL_VERSIONS.first

  WRITE_TOOLS = %w[create_memory update_memory].freeze

  # POST /mcp
  def call
    body = JSON.parse(request.body.read)

    # JSON-RPC notifications carry no id (e.g. notifications/initialized).
    # Per the Streamable HTTP transport, acknowledge with 202 and no body.
    return head :accepted if body["id"].nil?

    @jsonrpc_id = body["id"]
    render json: handle_rpc(body)
  rescue JSON::ParserError
    render json: jsonrpc_error(nil, -32_700, "Parse error"), status: :bad_request
  end

  private

  def handle_rpc(body)
    case body["method"]
    when "initialize" then handle_initialize(body["params"] || {})
    when "tools/list" then handle_tools_list
    when "tools/call" then handle_tool_call(body["params"] || {})
    when "ping" then jsonrpc_result({})
    else
      jsonrpc_error(@jsonrpc_id, -32_601, "Method not found: #{body["method"]}")
    end
  end

  def handle_initialize(params)
    requested = params["protocolVersion"]
    version = SUPPORTED_PROTOCOL_VERSIONS.include?(requested) ? requested : LATEST_PROTOCOL_VERSION

    response.set_header("Mcp-Session-Id", SecureRandom.uuid)
    jsonrpc_result(
      protocolVersion: version,
      capabilities: {tools: {}},
      serverInfo: {name: "recuerd0", version: "1.0.0"}
    )
  end

  def handle_tools_list
    jsonrpc_result(tools: Mcp::ToolDefinitions::ALL)
  end

  def handle_tool_call(params)
    name = params["name"]
    return jsonrpc_error(@jsonrpc_id, -32_601, "Unknown tool: #{name}") unless Mcp::ToolDefinitions.exists?(name)
    if WRITE_TOOLS.include?(name) && !@current_oauth_token.full_access?
      return jsonrpc_error(@jsonrpc_id, -32_001, "Insufficient scope — write access required")
    end

    value = Mcp::Tools.public_send(name, @mcp_account, params["arguments"] || {})
    jsonrpc_result(content: [{type: "text", text: value.to_json}])
  rescue Mcp::ToolError => e
    jsonrpc_result(content: [{type: "text", text: e.message}], isError: true)
  end

  def jsonrpc_result(result)
    {jsonrpc: "2.0", result: result, id: @jsonrpc_id}
  end

  def jsonrpc_error(id, code, message)
    {jsonrpc: "2.0", error: {code: code, message: message}, id: id}
  end
end
