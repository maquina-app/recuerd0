# Who answers for a thing, kept apart from who wrote it: passing ownership must not
# make the history claim someone else created it. Only roots carry an owner, because
# a version belongs to whoever owns its memory. Nullable like created_by: no owner
# means the account admin.
class AddOwnerToWorkspacesAndMemories < ActiveRecord::Migration[8.0]
  FIRST_ADMIN = <<~SQL.squish
    SELECT admins.id FROM users AS admins
    WHERE admins.account_id = %{account_id} AND admins.role = 'admin' AND admins.email_address NOT LIKE 'deleted-%%'
    ORDER BY admins.created_at, admins.id LIMIT 1
  SQL
  FORMER_MEMBERS = "SELECT id FROM users WHERE email_address LIKE 'deleted-%'"

  def up
    add_reference :workspaces, :owner, foreign_key: {to_table: :users, on_delete: :nullify}, null: true
    add_reference :memories, :owner, foreign_key: {to_table: :users, on_delete: :nullify}, null: true

    execute "UPDATE workspaces SET owner_id = created_by_id"
    execute "UPDATE memories SET owner_id = created_by_id WHERE parent_memory_id IS NULL"

    # Content from earlier removals gets the same default as a removal from now on.
    execute <<~SQL.squish
      UPDATE workspaces SET owner_id = (#{format(FIRST_ADMIN, account_id: "workspaces.account_id")})
      WHERE created_by_id IN (#{FORMER_MEMBERS})
    SQL
    execute <<~SQL.squish
      UPDATE memories SET owner_id = (#{format(FIRST_ADMIN, account_id: "(SELECT workspaces.account_id FROM workspaces WHERE workspaces.id = memories.workspace_id)")})
      WHERE parent_memory_id IS NULL AND created_by_id IN (#{FORMER_MEMBERS})
    SQL
  end

  def down
    remove_reference :memories, :owner, foreign_key: {to_table: :users, on_delete: :nullify}
    remove_reference :workspaces, :owner, foreign_key: {to_table: :users, on_delete: :nullify}
  end
end
