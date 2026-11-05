class AddChangeNoteToMemories < ActiveRecord::Migration[8.0]
  def change
    add_column :memories, :change_note, :string
  end
end
