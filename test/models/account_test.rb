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
  test "seed_start_here_workspace creates My Workspace" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "My Workspace")
    assert workspace.present?, "Expected 'My Workspace' to exist"
  end

  test "seed_start_here_workspace creates four memories in boot order" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "My Workspace")
    assert_equal 4, workspace.memories.count
    assert_equal [
      WorkspaceStarter::TITLE,
      "Continuation Brief",
      "Index — decisions",
      "D001 — Keep this workspace flat until ~20 memories"
    ],
      workspace.memories.order(:id).pluck(:title)

    map_memory = workspace.memories.order(:id).first
    assert_equal 1, workspace.memories.where(
      title: WorkspaceStarter::TITLE,
      parent_memory_id: nil
    ).count
    assert_equal WorkspaceStarter.content(
      base_url: "https://example.com",
      routing_bullets: StartHereContent::MAP_ROUTING_BULLETS
    ), map_memory.content.body.content
    StartHereContent::MAP_ROUTING_BULLETS.each do |routing_bullet|
      assert_includes map_memory.content.body.content, routing_bullet
    end
    assert_not_includes map_memory.content.body.content, "recuerd0.ai"
    assert_not_includes map_memory.content.body.content, "Create an access token"

    decision_memory = workspace.memories.find_by!(
      title: "D001 — Keep this workspace flat until ~20 memories"
    )
    assert_equal "decision", decision_memory.category

    default_listing = workspace.memories.latest_versions
      .ordered_by(Memory.resolve_sort(nil, query: nil))
    assert_equal WorkspaceStarter::TITLE, default_listing.first.title
  end

  test "seed_start_here_workspace memories have content" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "My Workspace")
    workspace.memories.each do |memory|
      assert memory.content.present?, "Expected memory '#{memory.title}' to have content"
      assert memory.content.body.content.present?, "Expected memory '#{memory.title}' to have non-empty body"
    end
  end

  test "seed_start_here_workspace sets source to system" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "My Workspace")
    workspace.memories.each do |memory|
      assert_equal "system", memory.source, "Expected memory '#{memory.title}' source to be 'system'"
    end
  end

  test "seed_start_here_workspace persists and pins the seed-defined defaults in creation order" do
    account = accounts(:one)
    user = users(:one)

    account.seed_start_here_workspace(user)

    workspace = account.workspaces.find_by(name: "My Workspace")
    seeded = workspace.memories.order(:id).to_a
    expected_defaults = StartHereContent::MEMORIES.map { |entry| entry[:pinned] }

    assert_equal expected_defaults, seeded.map(&:default_pinned?)
    assert_equal seeded.zip(expected_defaults).filter_map { |memory, pinned| memory.id if pinned },
      user.pins.for_memories
        .where(pinnable_id: workspace.memories.select(:id))
        .order(:position)
        .pluck(:pinnable_id)
  end

  test "ordinary memories are not default pinned" do
    memory = Memory.create_with_content(
      workspaces(:one),
      title: "Ordinary",
      content: "Not an account default"
    )

    assert_not memory.default_pinned?
  end

  test "new teammates receive active account defaults once and duplicate pins are skipped" do
    account = Account.create!(name: "Team defaults")
    creator = account.users.create!(
      email_address: "default-creator@example.com",
      password: "password",
      role: "admin"
    )
    account.seed_start_here_workspace(creator)
    defaults = account.workspaces.first.memories.where(default_pinned: true).order(:id).to_a
    archived_workspace = account.workspaces.create!(
      name: "Archived defaults",
      archived_at: Time.current
    )
    archived_default = Memory.create_with_content(
      archived_workspace,
      title: "Inactive default",
      content: "Do not pin",
      default_pinned: true
    )

    teammate = account.users.create!(
      email_address: "default-teammate@example.com",
      password: "password",
      role: "member"
    )

    assert_equal defaults.map(&:id),
      teammate.pins.for_memories.order(:pinnable_id).pluck(:pinnable_id)
    assert_not teammate.pins.exists?(pinnable: archived_default)
    assert_no_difference -> { teammate.pins.count } do
      teammate.send(:pin_account_defaults)
    end
  end

  test "creating a user in an unseeded account does not raise or create pins" do
    account = Account.create!(name: "Blank account")

    user = assert_nothing_raised do
      account.users.create!(
        email_address: "blank-account@example.com",
        password: "password",
        role: "admin"
      )
    end

    assert_predicate user, :persisted?
    assert_empty user.pins
  end

  test "create_with_user seeds My Workspace" do
    user = Account.create_with_user(
      email_address: "starhere@test.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert user.persisted?
    workspace = user.account.workspaces.find_by(name: "My Workspace")
    assert workspace.present?, "Expected 'My Workspace' on new account"
    assert_equal 4, workspace.memories.count
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
