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

  # The toast used to read a bare "Unpinned." against the only cross-workspace
  # index the user has: no name to search for and no way back.
  test "destroy names what was unpinned and offers a way back" do
    memory = memories(:one)
    memory.pin!(@user) unless memory.pinned_by?(@user)

    delete destroy_pin_url("Memory", memory)

    assert_equal I18n.t("pins.destroy.destroyed", title: memory.display_title), flash[:notice]
    assert_equal({"type" => "Memory", "id" => memory.id.to_s}, flash[:undo_pin])
  end

  test "create names what was pinned" do
    memory = memories(:versioned_parent)
    post create_pin_url("Memory", memory)

    assert_equal I18n.t("pins.create.created", title: memory.display_title), flash[:notice]
  end

  # The regression this whole change exists for: a pin is one person's, and
  # nothing one user does to their own board may show up on another's.
  test "pinning leaves a teammate's pinned set and budget untouched" do
    bob = users(:member)
    before_ids = bob.pinned_memories.pluck(:id)
    before_count = bob.pinned_items_count

    assert_difference("Pin.count", 1) do
      post create_pin_url("Memory", memories(:versioned_parent))
    end

    assert_equal before_ids, bob.reload.pinned_memories.pluck(:id)
    assert_equal before_count, bob.pinned_items_count
  end

  test "creating a workspace does not spend a teammate's budget" do
    bob = users(:member)
    before_count = bob.pinned_items_count

    assert_difference("bob.pins.count", 1) do
      post workspaces_url, params: {workspace: {name: "Alice's new workspace"}}
    end

    assert_equal before_count, bob.reload.pinned_items_count
    assert_equal "system", bob.pins.order(:created_at).last.origin
  end

  # A pin the app placed and the person removed stays removed: no later
  # system-pinning call site fires for that pair again.
  test "unpinning a system pin survives another workspace being created" do
    map = workspaces(:one).starter_map || Memory.create_with_content(workspaces(:one), title: "Map", content: "Body")
    map.pin!(@user, origin: "system") unless map.pinned_by?(@user)

    delete destroy_pin_url("Memory", map)
    assert_not map.reload.pinned_by?(@user)

    post workspaces_url, params: {workspace: {name: "Another workspace"}}

    assert_not map.reload.pinned_by?(@user)
  end
end
