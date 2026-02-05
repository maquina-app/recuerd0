class AddAccountToUsersAndWorkspaces < ActiveRecord::Migration[8.0]
  def up
    # Add account_id to users (nullable initially for data migration)
    add_reference :users, :account, foreign_key: true

    # Add account_id to workspaces (nullable initially for data migration)
    add_reference :workspaces, :account, foreign_key: true

    # Migrate existing data: create account for each user, assign workspaces
    execute <<~SQL
      INSERT INTO accounts (name, created_at, updated_at)
      SELECT
        SUBSTR(email_address, 1, INSTR(email_address, '@') - 1),
        created_at,
        updated_at
      FROM users
    SQL

    # Update users with their account_id (match by position/order)
    execute <<~SQL
      UPDATE users
      SET account_id = (
        SELECT accounts.id
        FROM accounts
        WHERE accounts.name = SUBSTR(users.email_address, 1, INSTR(users.email_address, '@') - 1)
        AND accounts.created_at = users.created_at
        LIMIT 1
      )
    SQL

    # Update workspaces with account_id from their user
    execute <<~SQL
      UPDATE workspaces
      SET account_id = (
        SELECT users.account_id
        FROM users
        WHERE users.id = workspaces.user_id
      )
    SQL

    # Now make account_id required on users
    change_column_null :users, :account_id, false

    # Make account_id required on workspaces
    change_column_null :workspaces, :account_id, false

    # Remove user_id from workspaces (no longer needed)
    remove_foreign_key :workspaces, :users
    remove_reference :workspaces, :user
  end

  def down
    # Add user_id back to workspaces
    add_reference :workspaces, :user, foreign_key: true

    # Restore user_id from account's first user
    execute <<~SQL
      UPDATE workspaces
      SET user_id = (
        SELECT users.id
        FROM users
        WHERE users.account_id = workspaces.account_id
        LIMIT 1
      )
    SQL

    change_column_null :workspaces, :user_id, false

    # Remove account_id from workspaces
    remove_reference :workspaces, :account

    # Remove account_id from users
    remove_reference :users, :account

    # Delete accounts
    execute "DELETE FROM accounts"
  end
end
