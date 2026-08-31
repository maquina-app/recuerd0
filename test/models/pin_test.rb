require "test_helper"

class PinTest < ActiveSupport::TestCase
  test "origin defaults to user" do
    pin = Pin.new(user: users(:member), pinnable: memories(:one))

    assert pin.valid?
    assert_equal "user", pin.origin
  end

  test "origin must be present and one of ORIGINS" do
    pin = Pin.new(user: users(:member), pinnable: memories(:one), origin: nil)
    assert_not pin.valid?
    assert_includes pin.errors.attribute_names, :origin

    pin.origin = "robot"
    assert_not pin.valid?
    assert_includes pin.errors.attribute_names, :origin

    pin.origin = "system"
    assert pin.valid?
  end

  test "user_origin and system_origin partition a user's pins" do
    user_pins = users(:one).pins
    assert_equal user_pins.count, user_pins.user_origin.count
    assert_empty user_pins.system_origin

    member_pins = users(:member).pins
    assert_empty member_pins.user_origin
    assert_equal [pins(:member_system_memory_pin)], member_pins.system_origin.to_a
  end
end
