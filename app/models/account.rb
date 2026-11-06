class Account < ApplicationRecord
  include SoftDeletable

  USER_LIMIT = 10

  has_many :users, dependent: :destroy
  has_many :workspaces, dependent: :destroy
  has_many :account_exports, dependent: :destroy
  has_many :invitations, dependent: :delete_all
  # Permanently removed means these too: an event can hold what someone searched for.
  has_many :analytics_events, class_name: "Analytics::Event", dependent: :delete_all
  has_many :analytics_api_requests, class_name: "Analytics::ApiRequest", dependent: :delete_all

  validates :name, presence: true

  # Creates an account with a user in a single transaction.
  # The first user is always an admin.
  # Seeds a "My Workspace" workspace with onboarding memories.
  # Returns the user on success, or an invalid user object on failure.
  def self.create_with_user(account_name:, email_address:, password:, password_confirmation:)
    account = new(name: account_name)
    user = account.users.build(
      account_name: account_name,
      email_address: email_address,
      password: password,
      password_confirmation: password_confirmation,
      role: "admin"
    )

    unless account.valid?
      account.errors.where(:name).each { |error| user.errors.add(:account_name, error.type) }
      return user
    end

    transaction do
      account.save!
      account.seed_start_here_workspace(user)
      user
    end
  rescue ActiveRecord::RecordInvalid => e
    e.record
  rescue ActiveRecord::RecordNotUnique
    user = User.new(account_name: account_name, email_address: email_address)
    user.errors.add(:email_address, :taken)
    user
  end

  def active_users
    users.active
  end

  # Receives what a removed user owned unless someone else is chosen.
  def first_admin
    active_users.where(role: "admin").order(:created_at, :id).first
  end

  # A name nobody chose, on an account from before signup asked for one, is the owner's
  # email prefix: it means nothing to the person invited, and it gives away part of
  # the owner's email.
  def named?
    owner_email = users.where(role: "admin").order(:created_at).pick(:email_address)

    owner_email.blank? || name != owner_email.split("@").first
  end

  def active_users_count
    active_users.count
  end

  def at_user_limit?
    return false unless Rails.application.config.multi_tenant

    active_users_count >= USER_LIMIT
  end

  def user_limit
    Rails.application.config.multi_tenant ? USER_LIMIT : nil
  end

  def generate_invitation_token
    invitations.create!.token
  end

  # Used links stay, so opening one again can say it was used rather than invalid.
  def revoke_invitations!
    invitations.unused.delete_all
  end

  # Deleting starts the grace period the Terms promise. Nothing is anonymized or
  # removed, so signing back in can still reach Restore and Export, and the email
  # cannot register a second account in the meantime. Every session ends now.
  def schedule_deletion!
    transaction do
      soft_delete
      Session.where(user_id: users.select(:id)).delete_all
    end
  end

  def permanent_deletion_on
    return unless deleted?

    (deleted_at + RETENTION_DAYS.days).to_date
  end

  # The end of the grace period. Workspaces first, one by one: dependent: :destroy
  # would only soft-delete them (SoftDeletable#destroy) and then trip the foreign
  # key on accounts.
  def purge!
    workspaces.find_each(&:destroy!)
    workspaces.reset
    destroy!
  end

  def seed_start_here_workspace(user)
    workspace = workspaces.create!(name: "My Workspace")
    map_data, *remaining_memories = StartHereContent::MEMORIES
    map = workspace.starter_map
    map.pin!(user, origin: "system")

    remaining_memories.each do |memory_data|
      memory = Memory.create_with_content(workspace,
        title: memory_data[:title],
        content: memory_data[:content].gsub("__BASE_URL__", Rails.application.config.x.app_base_url),
        tags: memory_data[:tags],
        category: memory_data[:category],
        source: "system",
        default_pinned: memory_data[:pinned])

      memory.pin!(user, origin: "system") if memory_data[:pinned]
    end

    map.update_with_content(
      content: map_data[:content].gsub("__BASE_URL__", Rails.application.config.x.app_base_url)
    )
    raise ActiveRecord::RecordInvalid, map if map.errors.any?

    map.touch
  end
end
