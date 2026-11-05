class Account < ApplicationRecord
  include SoftDeletable

  USER_LIMIT = 10

  has_many :users, dependent: :destroy
  has_many :workspaces, dependent: :destroy
  has_many :account_exports, dependent: :destroy

  validates :name, presence: true

  # Creates an account with a user in a single transaction.
  # The first user is always an admin.
  # Seeds a "My Workspace" workspace with onboarding memories.
  # Returns the user on success, or an invalid user object on failure.
  def self.create_with_user(email_address:, password:, password_confirmation:)
    transaction do
      account_name = email_address.to_s.split("@").first.presence || "Account"
      account = create!(name: account_name)
      user = account.users.create!(
        email_address: email_address,
        password: password,
        password_confirmation: password_confirmation,
        role: "admin"
      )
      account.seed_start_here_workspace(user)
      user
    end
  rescue ActiveRecord::RecordInvalid => e
    e.record
  rescue ActiveRecord::RecordNotUnique
    user = User.new(email_address: email_address)
    user.errors.add(:email_address, :taken)
    user
  end

  def active_users
    users.active
  end

  # How an invitation names this account. An account name nobody chose is just
  # the owner's email prefix, which means nothing to the person invited.
  def invitation_name
    owner_email = users.where(role: "admin").order(:created_at).pick(:email_address)
    return name if owner_email.blank? || name != owner_email.split("@").first

    I18n.t("invitations.show.owner_team", email: owner_email)
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
    Rails.application.message_verifier(:account_invitations)
      .generate([id, invitation_generation], expires_in: 7.days)
  end

  # Links signed before generations existed carry a bare id, which reads as
  # generation 0 and stays valid until they expire or the admin revokes.
  def self.find_by_invitation_token(token)
    payload = Rails.application.message_verifier(:account_invitations).verified(token)
    return nil unless payload

    account_id, generation = Array(payload)
    account = find_by(id: account_id)
    return nil if account.nil? || account.deleted?
    return nil unless account.invitation_generation == generation.to_i

    account
  end

  def revoke_invitations!
    increment!(:invitation_generation)
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
