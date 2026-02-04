class CreateMemoriesSearch < ActiveRecord::Migration[8.0]
  def change
    create_virtual_table :memories_search, :fts5,
      ["title", "body", "memory_id UNINDEXED", "tokenize='trigram'"]
  end
end
