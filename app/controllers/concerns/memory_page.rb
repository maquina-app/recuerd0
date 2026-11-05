# What memories/show needs, whether it was reached through the memory's stable
# URL or a specific version's.
module MemoryPage
  extend ActiveSupport::Concern

  private

  def prepare_memory_page(memory)
    @memory = memory
    @root_memory = memory.root_memory
    @all_versions = memory.all_versions.to_a
    @viewing_old_version = memory.versioned? && !memory.current_version?
  end
end
