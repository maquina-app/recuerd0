class AccessToken < ApplicationRecord
  PERMISSIONS = %w[read_only full_access].freeze
  WRITE_SCOPE = "memories:write"

  belongs_to :user
  belongs_to :oauth_client, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :manual, -> { where(oauth_client_id: nil) }
  scope :oauth, -> { where.not(oauth_client_id: nil) }
  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where.not(expires_at: nil).where("expires_at <= ?", Time.current) }

  attr_reader :raw_token, :raw_refresh_token

  validates :permission, presence: true, inclusion: {in: PERMISSIONS}
  validates :description, length: {maximum: 60}, allow_blank: true

  before_create :assign_access_token!

  # Looks up a usable (non-revoked, non-expired) token by its raw value.
  # Manual API tokens have nil expiry/revoked_at, so they remain valid here.
  def self.find_by_token(raw_token)
    return nil if raw_token.blank?
    active.find_by(token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  # Refresh tokens stay usable after the access token's short expiry — that is
  # their purpose — so this is gated only on revocation, not on expires_at.
  def self.find_by_refresh_token(raw_token)
    return nil if raw_token.blank?
    where(revoked_at: nil).find_by(refresh_token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  # Maps a granted OAuth scope string to the two-tier permission model.
  def self.permission_for_scope(scope)
    scope.to_s.split.include?(WRITE_SCOPE) ? "full_access" : "read_only"
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

  # Rotates the access token, exposing the new raw value via #raw_token.
  def assign_access_token!
    @raw_token = SecureRandom.base58(32)
    self.token_digest = Digest::SHA256.hexdigest(@raw_token)
    @raw_token
  end

  # Issues/rotates the refresh token, exposing the raw value via #raw_refresh_token.
  def assign_refresh_token!
    @raw_refresh_token = SecureRandom.base58(48)
    self.refresh_token_digest = Digest::SHA256.hexdigest(@raw_refresh_token)
    @raw_refresh_token
  end

  def revoke!
    update_column(:revoked_at, Time.current)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end
end
