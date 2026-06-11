class AddOauthFieldsToAccessTokens < ActiveRecord::Migration[8.1]
  def change
    add_reference :access_tokens, :oauth_client, null: true, foreign_key: true
    add_column :access_tokens, :expires_at, :datetime
    add_column :access_tokens, :refresh_token_digest, :string
    add_column :access_tokens, :oauth_scope, :string
    add_column :access_tokens, :revoked_at, :datetime

    add_index :access_tokens, :refresh_token_digest, unique: true
  end
end
