class AddRoleToUsersAndDeletedAtToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, null: false, default: "member"
    add_index :users, :role

    add_column :accounts, :deleted_at, :datetime
    add_index :accounts, :deleted_at

    reversible do |dir|
      dir.up do
        # Set all existing users to admin (they are account creators)
        execute "UPDATE users SET role = 'admin'"
      end
    end
  end
end
