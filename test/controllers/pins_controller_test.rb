require "test_helper"

class PinsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "create pins a memory" do
    assert_difference("Pin.count") do
      post create_pin_url("Memory", memories(:versioned_parent))
    end
  end

  test "destroy unpins a workspace" do
    assert_difference("Pin.count", -1) do
      delete destroy_pin_url("Workspace", workspaces(:one))
    end
  end

  # Turbo follows redirects with fetch, which keeps the original method through
  # a 302 for every verb but POST — so a 302 out of a DELETE re-issues the
  # DELETE against the redirect target. These must be 303.
  test "create redirects with see_other so Turbo does not replay the POST" do
    post create_pin_url("Memory", memories(:versioned_parent))
    assert_response :see_other
  end

  test "destroy redirects with see_other so Turbo does not replay the DELETE" do
    delete destroy_pin_url("Workspace", workspaces(:one))
    assert_response :see_other
  end
end
