# Represents a registered OAuth 2.1 client (e.g., Claude Desktop, Claude.ai).
# Clients registered via Dynamic Client Registration (RFC 7591) are public
# clients (token_endpoint_auth_method: "none") and authenticate using PKCE only.
class OauthClient < ApplicationRecord
  has_many :oauth_authorization_codes, dependent: :destroy
  has_many :access_tokens, dependent: :nullify

  validates :client_id, presence: true, uniqueness: true
  validates :client_name, presence: true
  validates :redirect_uris, presence: true
  validate :redirect_uris_well_formed

  before_validation :assign_client_id, on: :create

  def redirect_uri_list
    JSON.parse(redirect_uris)
  rescue JSON::ParserError
    []
  end

  def redirect_uri_allowed?(uri)
    redirect_uri_list.include?(uri)
  end

  def public_client?
    client_secret_digest.blank?
  end

  private

  # RFC 7591 / OAuth 2.1 BCP: validate redirect URIs at registration time.
  # Require absolute https URIs; permit http only for loopback (native-app dev).
  def redirect_uris_well_formed
    return if redirect_uris.blank? # presence validation already reports this

    uris = redirect_uri_list
    if uris.empty?
      errors.add(:redirect_uris, "must be a JSON array of at least one URI")
      return
    end

    uris.each { |uri| validate_single_redirect_uri(uri) }
  end

  def validate_single_redirect_uri(uri)
    parsed = URI.parse(uri.to_s)
    if parsed.scheme == "https"
      # ok
    elsif parsed.scheme == "http" && loopback_host?(parsed.host)
      # ok — loopback for native/dev clients
    else
      errors.add(:redirect_uris, "#{uri} must be an absolute https URI (http allowed only for localhost)")
    end
  rescue URI::InvalidURIError
    errors.add(:redirect_uris, "#{uri} is not a valid URI")
  end

  def loopback_host?(host)
    %w[localhost 127.0.0.1 ::1].include?(host)
  end

  def assign_client_id
    self.client_id ||= SecureRandom.hex(16)
    self.registered_at ||= Time.current
  end
end
