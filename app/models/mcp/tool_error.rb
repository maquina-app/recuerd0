module Mcp
  # Raised by a tool when an argument is invalid or a record can't be found.
  # The MCP controller turns this into a JSON-RPC tool error (isError: true).
  class ToolError < StandardError; end
end
