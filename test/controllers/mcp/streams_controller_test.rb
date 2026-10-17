require "test_helper"

class Mcp::StreamsControllerTest < ActionDispatch::IntegrationTest
  test "a client asking for the SSE stream gets 405 instead of the docs page" do
    get "/mcp", headers: {"Accept" => "text/event-stream"}

    assert_response :method_not_allowed
    assert_equal "POST", response.headers["Allow"]
    assert_empty response.body
  end

  test "a client sending only the protocol version header gets 405" do
    get "/mcp", headers: {"MCP-Protocol-Version" => "2025-06-18"}

    assert_response :method_not_allowed
  end

  test "a browser still gets the MCP docs page" do
    get "/mcp"

    assert_response :success
    assert_equal "text/html", response.media_type
  end
end
