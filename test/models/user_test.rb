require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email to lowercase and stripped" do
    user = User.new(email_address: " FOO@BAR.COM ", password: "password")
    assert_equal "foo@bar.com", user.email_address
  end

  test "belongs to account" do
    assert_equal accounts(:one), users(:one).account
  end

  test "can_pin_more? returns true under limit" do
    assert users(:one).can_pin_more?
  end

  test "pinned_items_count reflects pins" do
    assert_equal 2, users(:one).pinned_items_count
  end
end
