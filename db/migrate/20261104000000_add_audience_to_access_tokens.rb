class AddAudienceToAccessTokens < ActiveRecord::Migration[8.0]
  def up
    add_column :access_tokens, :audience, :string
    add_column :oauth_authorization_codes, :resource, :string

    # Existing OAuth access tokens carry no audience and would now be refused.
    # Expire them; their refresh tokens survive, so clients refresh
    # transparently and come back with an audience-bound token.
    AccessToken.reset_column_information
    AccessToken.oauth.update_all(expires_at: Time.current)
  end

  def down
    remove_column :oauth_authorization_codes, :resource
    remove_column :access_tokens, :audience
  end
end
