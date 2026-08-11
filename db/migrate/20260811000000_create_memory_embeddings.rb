class CreateMemoryEmbeddings < ActiveRecord::Migration[8.1]
  def change
    create_table :memory_embeddings do |t|
      t.references :memory, null: false, foreign_key: {on_delete: :cascade}, index: {unique: true}
      t.string :model, null: false
      t.string :content_hash, null: false
      t.binary :vector, null: false

      t.timestamps
    end
  end
end
