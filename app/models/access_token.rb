class AccessToken < ApplicationRecord
  PERMISSIONS = %w[read_only full_access].freeze
  WRITE_SCOPE = "memories:write"
  # Two workers refreshing with the same token at once look like a replay, so
  # one within this long of the rotation is refused without revoking.
  REFRESH_REUSE_GRACE = 1.minute
  # A refresh token dies after this long without being used. Connected agents
  # refresh hourly, so only an abandoned grant reaches it.
  REFRESH_IDLE_TIMEOUT = 90.days

  belongs_to :user
  belongs_to :oauth_client, optional: true

  scope :recent, -> { order(created_at: :desc) }
  scope :manual, -> { where(oauth_client_id: nil) }
  scope :oauth, -> { where.not(oauth_client_id: nil) }
  scope :active, -> { where(revoked_at: nil).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :expired, -> { where.not(expires_at: nil).where("expires_at <= ?", Time.current) }
  # What still grants access through a refresh, whether or not the access token
  # has expired. Connected applications lists by this.
  scope :refreshable, -> { where(revoked_at: nil).where("COALESCE(refreshed_at, created_at) > ?", REFRESH_IDLE_TIMEOUT.ago) }

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
  # their purpose — so this is gated on revocation and idleness, not on expires_at.
  def self.find_by_refresh_token(raw_token)
    return nil if raw_token.blank?
    refreshable.find_by(refresh_token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  # The token whose refresh token this was before its last rotation.
  def self.find_by_rotated_refresh_token(raw_token)
    return nil if raw_token.blank?
    where(revoked_at: nil).find_by(previous_refresh_token_digest: Digest::SHA256.hexdigest(raw_token))
  end

  # Maps a granted OAuth scope string to the two-tier permission model.
  def self.permission_for_scope(scope)
    scope.to_s.split.include?(WRITE_SCOPE) ? "full_access" : "read_only"
  end

  # Issued through OAuth consent and bound to an audience. A token outlives its
  # client (`dependent: :nullify`), so the audience is what marks it.
  def oauth?
    oauth_client_id? || audience.present?
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
  # The digest being replaced is kept, so a replay of it can be recognised.
  def assign_refresh_token!
    self.previous_refresh_token_digest = refresh_token_digest
    @raw_refresh_token = SecureRandom.base58(48)
    self.refresh_token_digest = Digest::SHA256.hexdigest(@raw_refresh_token)
    @raw_refresh_token
  end

  def revoke!
    update_column(:revoked_at, Time.current)
  end

  # A rotated refresh token came back: the client lost the response, or someone
  # else holds a copy. OAuth 2.1 says to revoke the grant, since the server
  # can't tell which (§4.3.1).
  def revoke_for_refresh_reuse!
    revoke! if refreshed_at.nil? || refreshed_at < REFRESH_REUSE_GRACE.ago
  end

  # Revokes every token the person holds for this token's app. Each consent
  # issues a new row, so revoking only the one shown left a re-authorized app
  # connected through the others.
  def revoke_grant!
    user.access_tokens.where(oauth_client_id: oauth_client_id, revoked_at: nil).update_all(revoked_at: Time.current)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def revoked?
    revoked_at.present?
  end
end
