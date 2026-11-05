# JSON-RPC 2.0 endpoint implementing MCP protocol revision 2026-07-28 over HTTP.
# Stateless: there is no handshake and no session. Every request names its
# protocol version and client capabilities in `params._meta` and repeats the
# version, method and tool name in transport headers, which must agree.
# Each request is authenticated via an OAuth Bearer token (McpAuthenticatable).
# Rate-limited per token/IP to bound tool-call abuse from a compromised token.
class McpController < ApplicationController
  include McpAuthenticatable

  allow_unauthenticated_access # McpAuthenticatable enforces the Bearer token instead
  skip_forgery_protection
  skip_before_action :require_mcp_token, only: :unsupported_method

  # Per-token (not per-IP): agent tool calls arrive from shared egress IPs, and
  # an active turn can burst several calls. ~2/sec sustained per connection.
  rate_limit to: 120, within: 1.minute, only: :call,
    by: -> { @current_oauth_token&.id || request.remote_ip },
    with: -> { render json: jsonrpc_error(nil, -32_000, "Rate limit exceeded"), status: :too_many_requests }

  SUPPORTED_PROTOCOL_VERSIONS = %w[2026-07-28].freeze
  SERVER_INFO = {name: "recuerd0", version: "1.0.0"}.freeze

  PROTOCOL_VERSION_META = "io.modelcontextprotocol/protocolVersion"
  CLIENT_CAPABILITIES_META = "io.modelcontextprotocol/clientCapabilities"
  SERVER_INFO_META = "io.modelcontextprotocol/serverInfo"

  CACHE_SCOPE = "private"
  TOOLS_TTL_MS = 300_000
  DISCOVERY_TTL_MS = 3_600_000

  WRITE_TOOLS = %w[create_memory update_memory create_version link_memories unlink_memories].freeze

  # Tools that create a new record whose `source` we stamp with the calling app.
  SOURCE_STAMPED_TOOLS = %w[create_memory create_version].freeze

  # Raised while validating a request; carries the JSON-RPC error and HTTP status.
  class RequestError < StandardError
    attr_reader :code, :status, :data

    def initialize(code, message, status: :bad_request, data: nil)
      super(message)
      @code = code
      @status = status
      @data = data
    end
  end

  # POST /mcp
  def call
    body = JSON.parse(request.body.read)
    raise RequestError.new(-32_600, "Invalid Request") unless body.is_a?(Hash)

    # A body without an id is a notification: acknowledge with 202, no body.
    return head :accepted unless body.key?("id")

    @jsonrpc_id = body["id"]
    raise RequestError.new(-32_600, "Invalid Request: id must not be null") if @jsonrpc_id.nil?

    rpc_params = object_param(body["params"])
    reject_legacy_handshake!(body["method"], rpc_params)
    validate_meta!(object_param(rpc_params["_meta"]))
    validate_headers!(body["method"], rpc_params)

    render json: dispatch_rpc(body["method"], rpc_params)
  rescue JSON::ParserError
    render json: jsonrpc_error(nil, -32_700, "Parse error"), status: :bad_request
  rescue RequestError => e
    render json: jsonrpc_error(@jsonrpc_id, e.code, e.message, data: e.data), status: e.status
  end

  # GET /mcp (an SSE stream request) and DELETE /mcp (session teardown). This
  # server offers no stream and keeps no session, so both answer 405.
  def unsupported_method
    response.set_header("Allow", "POST")
    head :method_not_allowed
  end

  private

  # This revision has no handshake. A client still opening with one gets the versions
  # it could speak instead of a complaint about _meta keys it has never heard of.
  def reject_legacy_handshake!(method, params)
    return unless method == "initialize" && !object_param(params["_meta"]).key?(PROTOCOL_VERSION_META)

    raise RequestError.new(-32_022, "Unsupported protocol version",
      data: {supported: SUPPORTED_PROTOCOL_VERSIONS, requested: params["protocolVersion"]})
  end

  def validate_meta!(meta)
    [PROTOCOL_VERSION_META, CLIENT_CAPABILITIES_META].each do |key|
      raise RequestError.new(-32_602, "Missing required _meta key: #{key}") unless meta.key?(key)
    end

    requested = meta[PROTOCOL_VERSION_META]
    unless SUPPORTED_PROTOCOL_VERSIONS.include?(requested)
      raise RequestError.new(-32_022, "Unsupported protocol version",
        data: {supported: SUPPORTED_PROTOCOL_VERSIONS, requested: requested})
    end
  end

  def validate_headers!(method, params)
    expected = {
      "MCP-Protocol-Version" => object_param(params["_meta"])[PROTOCOL_VERSION_META],
      "Mcp-Method" => method
    }
    expected["Mcp-Name"] = params["name"] if method == "tools/call"

    expected.each do |header, value|
      actual = decode_header(request.headers[header])
      next if actual == value.to_s

      raise RequestError.new(-32_020,
        "Header mismatch: #{header} is #{actual.inspect} but the request body says #{value.to_s.inspect}")
    end
  end

  # Header values that aren't plain ASCII arrive as =?base64?<value>?=.
  def decode_header(value)
    return value unless value.is_a?(String)

    match = value.match(/\A=\?base64\?(.*)\?=\z/)
    match ? Base64.strict_decode64(match[1]).force_encoding(Encoding::UTF_8) : value
  rescue ArgumentError
    value
  end

  def dispatch_rpc(method, params)
    case method
    when "server/discover" then handle_discover
    when "tools/list" then handle_tools_list
    when "tools/call" then handle_tool_call(params)
    else
      raise RequestError.new(-32_601,
        "Method not found: #{method} — this server supports protocol versions: #{SUPPORTED_PROTOCOL_VERSIONS.join(", ")}",
        status: :not_found)
    end
  end

  def handle_discover
    jsonrpc_result(
      supportedVersions: SUPPORTED_PROTOCOL_VERSIONS,
      capabilities: {tools: {}},
      ttlMs: DISCOVERY_TTL_MS,
      cacheScope: CACHE_SCOPE
    )
  end

  def handle_tools_list
    jsonrpc_result(tools: Mcp::ToolDefinitions::ALL, ttlMs: TOOLS_TTL_MS, cacheScope: CACHE_SCOPE)
  end

  def handle_tool_call(params)
    name = params["name"]
    return jsonrpc_error(@jsonrpc_id, -32_602, "Unknown tool: #{name}") unless Mcp::ToolDefinitions.exists?(name)
    insufficient_scope(name) if WRITE_TOOLS.include?(name) && !@current_oauth_token.full_access?

    arguments = object_param(params["arguments"])
    # `source` is server-authoritative: the authenticated OAuth client's name,
    # never whatever a client might pass. Stamped only on record creation.
    arguments["source"] = mcp_client_name if SOURCE_STAMPED_TOOLS.include?(name)

    value = Mcp::Tools.public_send(
      name,
      @mcp_account,
      arguments,
      user: @current_oauth_token.user
    )
    jsonrpc_result(content: [{type: "text", text: value.to_json}])
  rescue Mcp::ToolError => e
    jsonrpc_result(content: [{type: "text", text: e.message}], isError: true)
  end

  # 403 with a step-up challenge, so the client can ask for memories:write.
  def insufficient_scope(name)
    Rails.logger.info("[mcp] insufficient_scope tool=#{name} token_id=#{@current_oauth_token.id}")
    response.set_header("WWW-Authenticate",
      %(Bearer error="insufficient_scope", scope="#{AccessToken::WRITE_SCOPE}", resource_metadata="#{resource_metadata_url}"))
    raise RequestError.new(-32_001, "Insufficient scope — write access required", status: :forbidden)
  end

  def object_param(value)
    value.is_a?(Hash) ? value : {}
  end

  def mcp_client_name
    @current_oauth_token.oauth_client&.client_name
  end

  def jsonrpc_result(result)
    {jsonrpc: "2.0", result: result.merge(resultType: "complete", _meta: {SERVER_INFO_META => SERVER_INFO}), id: @jsonrpc_id}
  end

  def jsonrpc_error(id, code, message, data: nil)
    {jsonrpc: "2.0", error: {code: code, message: message, data: data}.compact, id: id}
  end
end
