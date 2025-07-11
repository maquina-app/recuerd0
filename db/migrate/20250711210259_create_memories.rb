class CreateMemories < ActiveRecord::Migration[8.0]
  def change
    create_table :memories do |t|
      t.string :title
      t.text :tags
      t.string :source
      t.references :workspace, null: false, foreign_key: true

      t.timestamps
    end
  end
end
