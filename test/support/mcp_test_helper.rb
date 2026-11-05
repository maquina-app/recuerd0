# Builds MCP 2026-07-28 requests: every call carries the protocol version and
# client capabilities in params._meta, and mirrors the version, method and
# tool name in the transport headers the server checks against the body.
module McpTestHelper
  MCP_PROTOCOL_VERSION = "2026-07-28"

  def mcp_meta(version: MCP_PROTOCOL_VERSION, capabilities: {})
    {
      McpController::PROTOCOL_VERSION_META => version,
      McpController::CLIENT_CAPABILITIES_META => capabilities
    }
  end

  def mcp_rpc(method, name: nil, arguments: nil, id: 1, meta: mcp_meta)
    params = {_meta: meta}
    params[:name] = name if name
    params[:arguments] = arguments if arguments
    {jsonrpc: "2.0", id: id, method: method, params: params}
  end

  # The headers a well-behaved client derives from the payload.
  def mcp_headers(payload)
    payload = payload.deep_stringify_keys
    params = payload["params"].is_a?(Hash) ? payload["params"] : {}
    meta = params["_meta"].is_a?(Hash) ? params["_meta"] : {}

    headers = {
      "Content-Type" => "application/json",
      "MCP-Protocol-Version" => meta[McpController::PROTOCOL_VERSION_META] || MCP_PROTOCOL_VERSION,
      "Mcp-Method" => payload["method"].to_s
    }
    headers["Mcp-Name"] = params["name"].to_s if payload["method"] == "tools/call"
    headers
  end

  # POSTs the payload with derived headers (override or drop with `headers:`,
  # where a nil value removes the header) and returns the parsed body.
  def mcp_post(payload, token: nil, headers: {})
    request_headers = mcp_headers(payload).merge(headers).compact
    request_headers["Authorization"] = "Bearer #{token}" if token
    post "/mcp", params: payload.to_json, headers: request_headers
    response.body.presence && JSON.parse(response.body)
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include McpTestHelper }
