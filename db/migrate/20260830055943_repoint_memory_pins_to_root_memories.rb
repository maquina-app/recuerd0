class RepointMemoryPinsToRootMemories < ActiveRecord::Migration[8.1]
  # Pins now always attach to a memory's root (Memory#pin_target). Existing
  # pins created from a version's show page still point at the version, where
  # they show a frozen snapshot and disagree with pinned_by? everywhere else.
  # Repoint them, collapsing any user who ended up pinning both the root and
  # one of its versions.
  def up
    execute <<~SQL.squish
      UPDATE pins
      SET pinnable_id = (
        SELECT memories.parent_memory_id FROM memories WHERE memories.id = pins.pinnable_id
      )
      WHERE pins.pinnable_type = 'Memory'
        AND EXISTS (
          SELECT 1 FROM memories
          WHERE memories.id = pins.pinnable_id AND memories.parent_memory_id IS NOT NULL
        )
    SQL

    execute <<~SQL.squish
      DELETE FROM pins
      WHERE pins.pinnable_type = 'Memory'
        AND pins.id NOT IN (
          SELECT MIN(id) FROM pins
          WHERE pinnable_type = 'Memory'
          GROUP BY user_id, pinnable_id
        )
    SQL
  end

  def down
    # The version a pin originally pointed at is not recoverable.
    raise ActiveRecord::IrreversibleMigration
  end
end
