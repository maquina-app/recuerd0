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

  test "soft_delete and restore update timestamp and deletion state" do
    account = accounts(:one)
    original_updated_at = account.updated_at

    travel 1.second do
      assert account.soft_delete
    end

    account.reload
    assert account.deleted?
    assert_operator account.updated_at, :>, original_updated_at

    deleted_updated_at = account.updated_at

    travel 2.seconds do
      account.restore
    end

    account.reload
    assert_not account.deleted?
    assert_operator account.updated_at, :>, deleted_updated_at
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

  test "at_user_limit? returns true at limit in multi-tenant mode" do
    account = accounts(:one)
    # Account one already has 2 users (one + member), add 8 more to reach 10
    8.times do |i|
      account.users.create!(
        email_address: "extra#{i}@example.com",
        password: "password",
        role: "member"
      )
    end
    assert account.at_user_limit?
  end

  test "at_user_limit? returns false in single-tenant mode regardless of user count" do
    account = accounts(:one)
    8.times do |i|
      account.users.create!(
        email_address: "extra#{i}@example.com",
        password: "password",
        role: "member"
      )
    end

    original = Rails.application.config.multi_tenant
    Rails.application.config.multi_tenant = false
    assert_not account.at_user_limit?
  ensure
    Rails.application.config.multi_tenant = original
  end

  test "user_limit returns USER_LIMIT in multi-tenant mode" do
    account = accounts(:one)
    assert_equal Account::USER_LIMIT, account.user_limit
  end

  test "user_limit returns nil in single-tenant mode" do
    account = accounts(:one)
    original = Rails.application.config.multi_tenant
    Rails.application.config.multi_tenant = false
    assert_nil account.user_limit
  ensure
    Rails.application.config.multi_tenant = original
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

  # seed_start_here_workspace tests
  test "seed_start_here_workspace creates Start Here workspace" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "Start Here")
    assert workspace.present?, "Expected 'Start Here' workspace to exist"
  end

  test "seed_start_here_workspace creates three memories in boot order" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "Start Here")
    assert_equal 3, workspace.memories.count
    assert_equal [
      "_MAP",
      "Continuation Brief",
      "_INDEX — Decisions"
    ],
      workspace.memories.order(:id).pluck(:title)

    default_listing = workspace.memories.latest_versions
      .ordered_by(Memory.resolve_sort(nil, query: nil))
    assert_equal "_MAP", default_listing.first.title
  end

  test "seed_start_here_workspace memories have content" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "Start Here")
    workspace.memories.each do |memory|
      assert memory.content.present?, "Expected memory '#{memory.title}' to have content"
      assert memory.content.body.content.present?, "Expected memory '#{memory.title}' to have non-empty body"
    end
  end

  test "seed_start_here_workspace sets source to system" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "Start Here")
    workspace.memories.each do |memory|
      assert_equal "system", memory.source, "Expected memory '#{memory.title}' source to be 'system'"
    end
  end

  test "seed_start_here_workspace pins exactly the map and continuation brief for user" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "Start Here")
    map_memory = workspace.memories.find_by(title: "_MAP")
    assert map_memory.pinned_by?(user), "Expected '_MAP' to be pinned for user"
    brief_memory = workspace.memories.find_by(title: "Continuation Brief")
    assert brief_memory.pinned_by?(user), "Expected 'Continuation Brief' to be pinned for user"
    index_memory = workspace.memories.find_by(title: "_INDEX — Decisions")
    assert_not index_memory.pinned_by?(user), "Expected '_INDEX — Decisions' NOT to be pinned"
  end

  test "create_with_user seeds Start Here workspace" do
    user = Account.create_with_user(
      email_address: "starhere@test.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert user.persisted?
    workspace = user.account.workspaces.find_by(name: "Start Here")
    assert workspace.present?, "Expected 'Start Here' workspace on new account"
    assert_equal 3, workspace.memories.count
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
