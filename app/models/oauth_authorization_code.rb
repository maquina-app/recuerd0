# Short-lived code issued after user consent, exchanged once for an access token.
# Implements PKCE S256 verification (RFC 7636).
class OauthAuthorizationCode < ApplicationRecord
  belongs_to :oauth_client
  belongs_to :user

  validates :code, :code_challenge, :redirect_uri, :expires_at, presence: true

  scope :active, -> { where("expires_at > ?", Time.current) }

  # Verifies a raw PKCE code_verifier against the stored S256 challenge.
  def pkce_valid?(verifier)
    expected = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier.to_s), padding: false)
    ActiveSupport::SecurityUtils.secure_compare(expected, code_challenge)
  end

  def expired?
    expires_at <= Time.current
  end
end
