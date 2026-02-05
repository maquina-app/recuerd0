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

  # Role tests
  test "validates role inclusion" do
    user = users(:one)
    user.role = "superadmin"
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end

  test "admin? returns true for admin role" do
    assert users(:one).admin?
    assert_not users(:one).member?
  end

  test "member? returns true for member role" do
    assert users(:member).member?
    assert_not users(:member).admin?
  end

  # Email anonymization tests
  test "anonymize_email! replaces name part with deleted-hex" do
    user = users(:member)
    original_domain = user.email_address.split("@").last

    user.anonymize_email!
    user.reload

    assert_match(/\Adeleted-[a-f0-9]{16}@#{original_domain}\z/, user.email_address)
  end

  test "anonymized? returns true for anonymized emails" do
    user = users(:member)
    assert_not user.anonymized?

    user.anonymize_email!
    assert user.anonymized?
  end
end
