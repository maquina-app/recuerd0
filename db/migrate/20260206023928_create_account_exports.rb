class CreateAccountExports < ActiveRecord::Migration[8.0]
  def change
    create_table :account_exports do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.datetime :completed_at
      t.datetime :expires_at
      t.text :error_message

      t.timestamps
    end

    add_index :account_exports, :expires_at
  end
end
