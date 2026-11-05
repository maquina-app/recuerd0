# A root row is v1 and also what filters read, so its tags and category follow the
# current version. These keep what v1 held once the two part ways. Rows that already
# parted have lost it, so they stay null and v1's history says nothing about them.
class AddFirstVersionFieldsToMemories < ActiveRecord::Migration[8.0]
  def change
    add_column :memories, :first_version_tags, :text
    add_column :memories, :first_version_category, :string
  end
end
