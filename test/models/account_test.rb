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

  # SoftDeletable tests
  test "includes SoftDeletable" do
    account = accounts(:one)
    assert_respond_to account, :soft_delete
    assert_respond_to account, :deleted?
  end

  test "soft_delete sets deleted_at" do
    account = accounts(:one)
    assert_nil account.deleted_at

    account.soft_delete
    account.reload
    assert account.deleted?
  end

  # create_with_user sets first user as admin
  test "create_with_user sets first user as admin" do
    user = Account.create_with_user(
      email_address: "newadmin@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    assert user.persisted?
    assert user.admin?
    assert_equal "admin", user.role
  end

  # User limit tests
  test "at_user_limit? returns false under limit" do
    account = accounts(:one)
    assert_not account.at_user_limit?
  end

  test "at_user_limit? returns true at limit" do
    account = accounts(:one)
    # Account one already has 2 users (one + member), add 3 more
    3.times do |i|
      account.users.create!(
        email_address: "extra#{i}@example.com",
        password: "password",
        role: "member"
      )
    end
    assert account.at_user_limit?
  end

  test "active_users_count excludes anonymized users" do
    account = accounts(:one)
    initial_count = account.active_users_count

    users(:member).anonymize_email!
    assert_equal initial_count - 1, account.active_users_count
  end

  # Invitation token tests
  test "generate_invitation_token creates a valid encrypted token" do
    account = accounts(:one)
    token = account.generate_invitation_token
    assert_not_nil token

    found = Account.find_by_invitation_token(token)
    assert_equal account, found
  end

  test "find_by_invitation_token returns nil for expired token" do
    account = accounts(:one)
    token = account.generate_invitation_token

    travel 8.days do
      assert_nil Account.find_by_invitation_token(token)
    end
  end

  test "find_by_invitation_token returns nil for invalid token" do
    assert_nil Account.find_by_invitation_token("garbage-token")
  end

  test "find_by_invitation_token returns nil for deleted account" do
    account = accounts(:one)
    token = account.generate_invitation_token
    account.soft_delete

    assert_nil Account.find_by_invitation_token(token)
  end

  # Anonymize users test
  test "anonymize_users! replaces all user emails and destroys sessions" do
    account = accounts(:one)
    assert account.users.count > 0

    account.anonymize_users!

    account.users.reload.each do |user|
      assert user.anonymized?, "Expected #{user.email_address} to be anonymized"
    end
    assert_equal 0, Session.where(user_id: account.user_ids).count
  end
end
