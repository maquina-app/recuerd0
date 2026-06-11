class CreateOauthClients < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_clients do |t|
      t.string :client_id, null: false
      t.string :client_secret_digest
      t.string :client_name, null: false
      t.text :redirect_uris, null: false
      t.string :grant_types, default: "authorization_code"
      t.string :scope, default: "memories:read memories:write workspaces:read"
      t.string :token_endpoint_auth_method, default: "none"
      t.datetime :registered_at, null: false

      t.timestamps
    end

    add_index :oauth_clients, :client_id, unique: true
  end
end
