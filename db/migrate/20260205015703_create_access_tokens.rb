class CreateAccessTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :access_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :description
      t.string :permission, null: false, default: "read_only"
      t.datetime :last_used_at

      t.timestamps
    end
    add_index :access_tokens, :token_digest, unique: true
  end
end
