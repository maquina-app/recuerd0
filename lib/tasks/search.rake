namespace :search do
  desc "Rebuild full-text search index for all memories or a specific workspace"
  task :reindex, [:workspace_id] => :environment do |_t, args|
    scope = Memory.latest_versions.includes(:content)

    if args[:workspace_id].present?
      workspace = Workspace.find(args[:workspace_id])
      scope = scope.where(workspace: workspace)
      puts "Re-indexing memories for workspace: #{workspace.name} (ID: #{workspace.id})"
    else
      puts "Re-indexing all memories..."
      ActiveRecord::Base.connection.execute("DELETE FROM memories_search")
    end

    count = 0
    scope.find_each do |memory|
      memory.rebuild_search_index
      count += 1
    end

    puts "Done. #{count} memories re-indexed."
  end
end
