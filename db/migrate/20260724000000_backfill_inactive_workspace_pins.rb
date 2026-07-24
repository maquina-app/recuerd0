class BackfillInactiveWorkspacePins < ActiveRecord::Migration[8.1]
  def up
    Workspace.where("archived_at IS NOT NULL OR deleted_at IS NOT NULL").find_each do |workspace|
      workspace.pins.destroy_all
    end
  end
end
