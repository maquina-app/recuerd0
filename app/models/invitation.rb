# A link for one person to join an account. The token is signed, so it expires on its
# own and carries no secret in the database; the row is what makes it single use.
class Invitation < ApplicationRecord
  EXPIRES_IN = 7.days

  belongs_to :account

  scope :unused, -> { where(used_at: nil) }

  def self.find_by_token(token)
    find_signed(token, purpose: :join_account)
  end

  def token
    signed_id(purpose: :join_account, expires_in: EXPIRES_IN)
  end

  def used?
    used_at.present?
  end

  # Saves the person and spends the link together, so a failed signup leaves it usable
  # and two people submitting at once cannot both join. False with the reason in
  # user.errors, or with the link already spent.
  def redeem(user)
    return false unless user.valid?

    transaction do
      raise ActiveRecord::Rollback unless claim

      user.save!
    end || false
  rescue ActiveRecord::RecordNotUnique
    user.errors.add(:email_address, :taken)
    false
  end

  private

  def claim
    self.class.unused.where(id: id).update_all(used_at: Time.current) == 1
  end
end
