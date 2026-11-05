# Ownership. Nullable on purpose: a row with no recorded creator belongs
# to the account admin, which covers everything created before this column and
# the seeded "My Workspace". ON DELETE SET NULL keeps a hard account purge from
# tripping over the foreign key when users go before their workspaces.
class AddCreatedByToWorkspacesAndMemories < ActiveRecord::Migration[8.0]
  def change
    add_reference :workspaces, :created_by, foreign_key: {to_table: :users, on_delete: :nullify}, null: true
    add_reference :memories, :created_by, foreign_key: {to_table: :users, on_delete: :nullify}, null: true
  end
end
