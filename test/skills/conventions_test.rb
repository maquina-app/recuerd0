require "test_helper"
require "digest"

class ConventionsTest < ActiveSupport::TestCase
  EXPECTED_SHA256 = "6868c4d42d7db4ae532baf258ef5400fd76229304b6bf1ca024801a432a506f5"

  test "MCP conventions match the reviewed artifact" do
    path = Rails.root.join("skills/recuerd0-mcp/references/conventions.md")

    assert_equal EXPECTED_SHA256, Digest::SHA256.file(path).hexdigest
  end
end
