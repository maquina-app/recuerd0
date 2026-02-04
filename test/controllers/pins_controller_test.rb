require "test_helper"

class PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create pins a memory" do
    assert_difference("Pin.count") do
      post create_pin_url("Memory", memories(:one))
    end
  end

  test "destroy unpins a workspace" do
    assert_difference("Pin.count", -1) do
      delete destroy_pin_url("Workspace", workspaces(:one))
    end
  end
end
