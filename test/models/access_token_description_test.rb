require "test_helper"

class AccessTokenDescriptionTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "description is stored correctly" do
    token = @user.access_tokens.create!(permission: "read_only", description: "My CI token")
    assert_equal "My CI token", token.reload.description
  end

  test "description rejects values over 60 characters" do
    token = @user.access_tokens.build(permission: "read_only", description: "a" * 61)
    assert_not token.valid?
    assert_includes token.errors[:description], "is too long (maximum is 60 characters)"
  end

  test "description allows blank value" do
    token = @user.access_tokens.create!(permission: "read_only", description: "")
    assert token.valid?
  end

  test "description allows nil value" do
    token = @user.access_tokens.create!(permission: "read_only")
    assert_nil token.description
    assert token.valid?
  end
end
