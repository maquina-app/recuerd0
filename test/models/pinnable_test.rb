require "test_helper"

# Origin behaviour of the Pinnable concern: who spends the budget, and what a
# second pin! call does to a pin that already exists.
class PinnableTest < ActiveSupport::TestCase
  setup do
    @user = users(:member)
    @workspace = workspaces(:one)
  end

  test "pin! creates a user-origin pin by default" do
    pin = memories(:one).pin!(@user)

    assert_equal "user", pin.origin
  end

  test "pin! raises for a user-origin pin once the budget is spent" do
    fill_budget

    memory = create_memory("Over budget")
    assert_no_difference("Pin.count") do
      error = assert_raises(ActiveRecord::RecordInvalid) { memory.pin!(@user) }
      assert_match I18n.t("models.pinnable.limit_reached", limit: User::PIN_LIMIT), error.message
    end
  end

  test "pin! never consults the budget for a system-origin pin" do
    fill_budget

    memory = create_memory("Placed by recuerd0")
    assert_difference("Pin.count", 1) do
      assert_equal "system", memory.pin!(@user, origin: "system").origin
    end
    assert_equal User::PIN_LIMIT, @user.pinned_items_count
  end

  test "pin! does not change the origin of an existing pin" do
    memory = memories(:one)
    memory.pin!(@user)

    assert_no_difference("Pin.count") { memory.pin!(@user, origin: "system") }
    assert_equal "user", memory.pin_origin_for(@user).to_s

    system_pinned = memories(:versioned_parent)
    assert_no_difference("Pin.count") { system_pinned.pin!(@user) }
    assert_equal "system", system_pinned.pin_origin_for(@user)
  end

  test "pin_origin_for reads a preloaded association without querying" do
    memory = Memory.where(id: memories(:versioned_parent).id).includes(:pins).first
    other_user = users(:one)

    assert_no_queries do
      assert_equal "system", memory.pin_origin_for(@user)
      assert_nil memory.pin_origin_for(other_user)
    end
  end

  test "pin_origin_for returns nil when unpinned" do
    assert_nil memories(:one).pin_origin_for(@user)
  end

  private

  def fill_budget
    User::PIN_LIMIT.times { |i| create_memory("Budget #{i}").pin!(@user) }
    assert_not @user.can_pin_more?
  end

  def create_memory(title)
    Memory.create_with_content(@workspace, title: title, content: "Body")
  end
end
