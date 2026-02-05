require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "validates presence of name" do
    account = Account.new(name: nil)
    assert_not account.valid?
    assert_includes account.errors[:name], "can't be blank"
  end

  test "has many users" do
    account = accounts(:one)
    assert_respond_to account, :users
    assert_includes account.users, users(:one)
  end

  test "has many workspaces" do
    account = accounts(:one)
    assert_respond_to account, :workspaces
    assert_includes account.workspaces, workspaces(:one)
  end

  test "user belongs to account and is required" do
    user = User.new(email_address: "test@example.com", password: "password")
    assert_not user.valid?
    assert_includes user.errors[:account], "must exist"
  end
end
