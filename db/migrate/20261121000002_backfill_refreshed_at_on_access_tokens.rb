# Refresh tokens now expire after REFRESH_IDLE_TIMEOUT without a refresh, read
# from refreshed_at. Rows from before that column existed take updated_at,
# which every rotation's save! moved, so an active grant isn't cut off.
class BackfillRefreshedAtOnAccessTokens < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE access_tokens SET refreshed_at = updated_at
      WHERE refreshed_at IS NULL AND refresh_token_digest IS NOT NULL
    SQL
  end

  def down
  end
end
