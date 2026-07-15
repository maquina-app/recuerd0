namespace :memories do
  desc "Reconcile each root memory's category with its current (latest) version's category"
  task backfill_root_category: :environment do
    updated = 0
    Memory.latest_versions.find_each do |root|
      current_category = root.current_version.category
      next if root.category == current_category

      root.update_column(:category, current_category)
      updated += 1
    end

    puts "Done. #{updated} root memories reconciled to their current version's category."
  end
end
