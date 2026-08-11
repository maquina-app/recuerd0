namespace :search do
  desc "Rebuild full-text search index for all memories or a specific workspace"
  task :reindex, [:workspace_id] => :environment do |_t, args|
    scope = Memory.latest_versions.includes(content: :markdown_body)

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

  desc "Backfill local embeddings for all root memories or a specific workspace"
  task :embed_backfill, [:workspace_id] => :environment do |_task, args|
    unless Rails.configuration.x.hybrid_retrieval
      abort "HYBRID_RETRIEVAL=true is required for search:embed_backfill"
    end

    provider = EmbeddingProviders.backfill
    scope = Memory.latest_versions
    scope = scope.where(workspace: Workspace.find(args[:workspace_id])) if args[:workspace_id].present?
    counts = Hash.new(0)

    scope.find_each do |memory|
      counts[memory.rebuild_embedding(provider: provider)] += 1
    end

    puts "#{counts[:embedded]} embedded, #{counts[:unchanged]} unchanged"
  end
end
