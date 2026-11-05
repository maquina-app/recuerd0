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
      account_name: "Test account",
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
    assert_equal map_memory, workspace.memories.order(updated_at: :desc).first
    assert_not_includes map_memory.content.body.content, "recuerd0.ai"
    assert_not_includes map_memory.content.body.content, "Create an access token"
    assert_not_includes map_memory.content.body.content, "Link memories that belong together."

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
      account_name: "Test account",
      email_address: "starhere@test.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert user.persisted?
    workspace = user.account.workspaces.find_by(name: "My Workspace")
    assert workspace.present?, "Expected 'My Workspace' on new account"
    assert_equal 4, workspace.memories.count
  end

  test "schedule_deletion! ends every session and keeps every email" do
    account = accounts(:one)
    users(:one).sessions.create!(ip_address: "1.1.1.1", user_agent: "Test")

    assert_no_changes -> { account.users.reload.map(&:email_address).sort } do
      account.schedule_deletion!
    end

    assert account.reload.deleted?
    assert_equal 0, Session.where(user_id: account.user_ids).count
    assert_equal (account.deleted_at + 30.days).to_date, account.permanent_deletion_on
  end

  test "purge! removes the account and everything under it" do
    account = Account.create_with_user(account_name: "Test account", email_address: "purge-me@example.com", password: "password123", password_confirmation: "password123").account
    workspace = account.workspaces.first
    workspace.memories.latest_versions.first.create_version!(content: "second version")
    client = OauthClient.create!(client_name: "Claude", redirect_uris: JSON.generate(["https://claude.ai/cb"]))
    client.oauth_authorization_codes.create!(user: account.users.first, code: "code", code_challenge: "challenge",
      redirect_uri: "https://claude.ai/cb", expires_at: 10.minutes.from_now)
    account.schedule_deletion!

    account.purge!

    assert_not Account.exists?(account.id)
    assert_not Workspace.exists?(workspace.id)
    assert_not User.exists?(email_address: "purge-me@example.com")
    assert_equal 0, Memory.where(workspace_id: workspace.id).count
  end
end
