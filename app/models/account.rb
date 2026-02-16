class Account < ApplicationRecord
  include SoftDeletable

  USER_LIMIT = 10

  has_many :users, dependent: :destroy
  has_many :workspaces, dependent: :destroy
  has_many :account_exports, dependent: :destroy

  validates :name, presence: true

  # Creates an account with a user in a single transaction.
  # The first user is always an admin.
  # Seeds a "Start Here" workspace with onboarding memories.
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
    Rails.application.message_verifier(:account_invitations).generate(id, expires_in: 7.days)
  end

  def self.find_by_invitation_token(token)
    account_id = Rails.application.message_verifier(:account_invitations).verified(token)
    return nil unless account_id

    account = find_by(id: account_id)
    return nil if account.nil? || account.deleted?

    account
  end

  def anonymize_users!
    transaction do
      users.each do |user|
        user.anonymize_email! unless user.anonymized?
        user.sessions.delete_all
      end
    end
  end

  def seed_start_here_workspace(user)
    workspace = workspaces.create!(name: "Start Here")

    StartHereContent::MEMORIES.each do |memory_data|
      memory = Memory.create_with_content(workspace,
        title: memory_data[:title],
        content: memory_data[:content],
        tags: memory_data[:tags],
        source: "system")

      memory.pin!(user) if memory_data[:pinned]
    end
  end
end
