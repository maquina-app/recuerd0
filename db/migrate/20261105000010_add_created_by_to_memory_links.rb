# Who may remove a link. Nullable on purpose: a link with no recorded creator belongs
# to the account admin, which covers every link made before this column. ON DELETE SET
# NULL hands a removed user's links to the admin instead of tripping the foreign key.
class AddCreatedByToMemoryLinks < ActiveRecord::Migration[8.0]
  def change
    add_reference :memory_links, :created_by, foreign_key: {to_table: :users, on_delete: :nullify}, null: true
  end
end
