# Removing a member used to end their sessions and leave their API tokens and MCP
# connections working, with nobody able to see or revoke them. Close the ones that
# are already out there.
class RevokeTokensOfRemovedUsers < ActiveRecord::Migration[8.0]
  REMOVED = "SELECT id FROM users WHERE email_address LIKE 'deleted-%'"

  def up
    execute "UPDATE access_tokens SET revoked_at = CURRENT_TIMESTAMP WHERE revoked_at IS NULL AND user_id IN (#{REMOVED})"
    execute "DELETE FROM oauth_authorization_codes WHERE user_id IN (#{REMOVED})"
  end

  def down
    # Revoked credentials stay revoked.
  end
end
