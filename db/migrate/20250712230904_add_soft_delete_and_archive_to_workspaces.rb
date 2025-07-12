class AddSoftDeleteAndArchiveToWorkspaces < ActiveRecord::Migration[8.0]
  def change
    add_column :workspaces, :deleted_at, :datetime
    add_index :workspaces, :deleted_at
    add_column :workspaces, :archived_at, :datetime
    add_index :workspaces, :archived_at
  end
end
