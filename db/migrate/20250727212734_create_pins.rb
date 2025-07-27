class CreatePins < ActiveRecord::Migration[8.0]
  def change
    create_table :pins do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pinnable, polymorphic: true, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    # Ensure a user can only pin an item once
    add_index :pins, [:user_id, :pinnable_type, :pinnable_id],
      unique: true,
      name: "index_pins_uniqueness"

    # Optimize queries for finding user's pins by type and position
    add_index :pins, [:user_id, :pinnable_type, :position],
      name: "index_pins_user_type_position"
  end
end
