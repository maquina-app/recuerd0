# The memory page now lives at the root's URL and reads links off the root, the
# same record REST and MCP read them from. Links created while viewing a version
# were stored against that version's row, so move them to the root. A pair that
# already exists, or that would link a memory to itself, is dropped.
class RepointMemoryLinksToRootMemories < ActiveRecord::Migration[8.0]
  def up
    roots = select_rows("SELECT id, parent_memory_id FROM memories WHERE parent_memory_id IS NOT NULL").to_h
    return if roots.empty?

    select_rows("SELECT id, from_memory_id, to_memory_id FROM memory_links ORDER BY id").each do |id, from, to|
      next unless roots.key?(from) || roots.key?(to)

      low, high = [roots.fetch(from, from), roots.fetch(to, to)].minmax
      duplicate = select_value("SELECT 1 FROM memory_links WHERE from_memory_id = #{low} AND to_memory_id = #{high} AND id != #{id}")

      if low == high || duplicate
        execute "DELETE FROM memory_links WHERE id = #{id}"
      else
        execute "UPDATE memory_links SET from_memory_id = #{low}, to_memory_id = #{high} WHERE id = #{id}"
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
