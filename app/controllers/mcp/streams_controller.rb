# GET /mcp from an MCP client asks for the server-to-client SSE stream.
# We offer none, and the Streamable HTTP transport says to answer 405 —
# a 200 makes the client treat the stream as closed and reconnect in a loop.
class Mcp::StreamsController < ApplicationController
  allow_unauthenticated_access

  def show
    response.set_header("Allow", "POST")
    head :method_not_allowed
  end
end
