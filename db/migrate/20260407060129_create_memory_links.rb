class CreateMemoryLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :memory_links do |t|
      t.references :from_memory, null: false, foreign_key: {to_table: :memories}
      t.references :to_memory, null: false, foreign_key: {to_table: :memories}
      t.timestamps
    end

    add_index :memory_links, [:from_memory_id, :to_memory_id], unique: true
  end
end
