class AddDefaultPinnedToMemories < ActiveRecord::Migration[8.1]
  def change
    add_column :memories, :default_pinned, :boolean, default: false, null: false
    add_index :memories, [:workspace_id, :default_pinned]
  end
end
