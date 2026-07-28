require "test_helper"
require "digest"

class ConventionsTest < ActiveSupport::TestCase
  EXPECTED_SHA256 = "6771db25678e7fd556d5bed62527cd713d3c7f0cafd43269e4242441465f1ddd"

  test "MCP conventions match the reviewed artifact" do
    path = Rails.root.join("skills/recuerd0-mcp/references/conventions.md")

    assert_equal EXPECTED_SHA256, Digest::SHA256.file(path).hexdigest
  end
end
