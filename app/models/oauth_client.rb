# Represents a registered OAuth 2.1 client (e.g., Claude Desktop, Claude.ai).
# Clients registered via Dynamic Client Registration (RFC 7591) are public
# clients (token_endpoint_auth_method: "none") and authenticate using PKCE only.
class OauthClient < ApplicationRecord
  has_many :oauth_authorization_codes, dependent: :destroy
  has_many :access_tokens, dependent: :nullify

  validates :client_id, presence: true, uniqueness: true
  validates :client_name, presence: true
  validates :redirect_uris, presence: true

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

  def assign_client_id
    self.client_id ||= SecureRandom.hex(16)
    self.registered_at ||= Time.current
  end
end
