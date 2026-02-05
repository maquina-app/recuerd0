class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :workspaces, dependent: :destroy

  validates :name, presence: true

  # Creates an account with a user in a single transaction.
  # Returns the user on success, or an invalid user object on failure.
  def self.create_with_user(email_address:, password:, password_confirmation:)
    transaction do
      account_name = email_address.to_s.split("@").first.presence || "Account"
      account = create!(name: account_name)
      account.users.create!(
        email_address: email_address,
        password: password,
        password_confirmation: password_confirmation
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    e.record
  rescue ActiveRecord::RecordNotUnique
    user = User.new(email_address: email_address)
    user.errors.add(:email_address, :taken)
    user
  end
end
