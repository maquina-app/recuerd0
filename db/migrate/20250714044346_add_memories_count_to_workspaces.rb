class AddMemoriesCountToWorkspaces < ActiveRecord::Migration[8.0]
  def change
    add_column :workspaces, :memories_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        Workspace.find_each do |workspace|
          Workspace.reset_counters(workspace.id, :memories)
        end
      end
    end
  end
end
