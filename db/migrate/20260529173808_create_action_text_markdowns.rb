class CreateActionTextMarkdowns < ActiveRecord::Migration[8.1]
  def change
    create_table :action_text_markdowns do |t|
      t.string :record_type, null: false
      t.integer :record_id, null: false
      t.string :name, null: false
      t.text :content, null: false, default: ""
      t.timestamps
      t.index [:record_type, :record_id], name: "index_action_text_markdowns_on_record"
    end

    add_column :active_storage_attachments, :slug, :string
    add_index :active_storage_attachments, :slug, unique: true
  end
end
