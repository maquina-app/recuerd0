# RFC 7009 token revocation. Claude calls this on disconnect.
# Rate-limited to prevent token enumeration via repeated revocation probing.
class Oauth::RevocationsController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection

  # Per-IP; generous since disconnects from many users can share egress.
  rate_limit to: 30, within: 1.minute, with: -> { head :too_many_requests }

  # POST /oauth/revoke
  def create
    digest = Digest::SHA256.hexdigest(params[:token].to_s)
    token = AccessToken.find_by(token_digest: digest) || AccessToken.find_by(refresh_token_digest: digest)
    token&.revoke!
    head :ok # RFC 7009: always 200, even for unknown tokens
  end
end
