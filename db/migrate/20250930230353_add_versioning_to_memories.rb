class AddVersioningToMemories < ActiveRecord::Migration[8.0]
  def change
    add_column :memories, :version, :integer, default: 1, null: false
    add_reference :memories, :parent_memory, null: true, foreign_key: {to_table: :memories}

    add_index :memories, [:parent_memory_id, :version]
    add_index :memories, :version
  end
end
