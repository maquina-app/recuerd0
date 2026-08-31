class AddOriginToPins < ActiveRecord::Migration[8.0]
  def change
    add_column :pins, :origin, :string, null: false, default: "user"
    add_index :pins, [:user_id, :origin]
  end
end
