# memories_count used to be a plain counter cache over every row, and each
# version is a row, so a memory with three versions counted as three.
class CountOnlyRootMemories < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE workspaces SET memories_count = (
        SELECT COUNT(*) FROM memories
        WHERE memories.workspace_id = workspaces.id AND memories.parent_memory_id IS NULL
      )
    SQL
  end

  def down
    execute <<~SQL
      UPDATE workspaces SET memories_count = (
        SELECT COUNT(*) FROM memories WHERE memories.workspace_id = workspaces.id
      )
    SQL
  end
end
