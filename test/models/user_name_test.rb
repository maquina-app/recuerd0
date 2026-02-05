require "test_helper"

class UserNameTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "name is optional" do
    user = users(:two)
    assert_nil user.name
    assert user.valid?
  end

  test "name can be set and retrieved" do
    @user.update!(name: "Alice Test")
    assert_equal "Alice Test", @user.reload.name
  end

  test "name rejects values over 80 characters" do
    @user.name = "a" * 81
    assert_not @user.valid?
    assert_includes @user.errors[:name], "is too long (maximum is 80 characters)"
  end

  test "name allows blank value" do
    @user.name = ""
    assert @user.valid?
  end
end
