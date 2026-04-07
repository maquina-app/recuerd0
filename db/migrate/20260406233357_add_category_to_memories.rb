class AddCategoryToMemories < ActiveRecord::Migration[8.0]
  def change
    add_column :memories, :category, :string, null: false, default: "general"
    add_index :memories, :category
  end
end
