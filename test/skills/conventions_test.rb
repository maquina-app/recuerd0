require "test_helper"
require "digest"

class ConventionsTest < ActiveSupport::TestCase
  EXPECTED_SHA256 = "80748cff478b274716aecbc9ec0e8a434e52187dbee87fcfe7e4652ff2a33173"

  test "MCP conventions match the reviewed artifact" do
    path = Rails.root.join("skills/recuerd0-mcp/references/conventions.md")

    assert_equal EXPECTED_SHA256, Digest::SHA256.file(path).hexdigest
  end
end
