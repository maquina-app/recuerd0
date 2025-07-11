class CreateContents < ActiveRecord::Migration[8.0]
  def change
    create_table :contents do |t|
      t.text :body
      t.references :memory, null: false, foreign_key: true

      t.timestamps
    end
  end
end
