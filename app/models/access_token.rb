class AccessToken < ApplicationRecord
  PERMISSIONS = %w[read_only full_access].freeze

  belongs_to :user

  attr_reader :raw_token

  validates :permission, presence: true, inclusion: {in: PERMISSIONS}
  validates :description, length: {maximum: 255}, allow_blank: true

  before_create :generate_token

  def self.find_by_token(raw_token)
    return nil if raw_token.blank?
    find_by(token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  def read_only?
    permission == "read_only"
  end

  def full_access?
    permission == "full_access"
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  private

  def generate_token
    @raw_token = SecureRandom.base58(32)
    self.token_digest = Digest::SHA256.hexdigest(@raw_token)
  end
end
