require "test_helper"

class ContentTest < ActiveSupport::TestCase
  test "belongs to memory" do
    assert_equal memories(:one), contents(:one).memory
  end

  test "touch propagates to parent memory" do
    memory = memories(:one)
    content = contents(:one)
    original_updated_at = memory.updated_at

    travel_to 1.minute.from_now do
      content.touch
      assert_operator memory.reload.updated_at, :>, original_updated_at
    end
  end
end
