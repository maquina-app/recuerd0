class AddRefreshRotationToAccessTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :access_tokens, :previous_refresh_token_digest, :string
    add_column :access_tokens, :refreshed_at, :datetime
    add_index :access_tokens, :previous_refresh_token_digest, unique: true
  end
end
