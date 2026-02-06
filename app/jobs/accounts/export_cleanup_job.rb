module Accounts
  class ExportCleanupJob < ApplicationJob
    queue_as :default
    discard_on ActiveRecord::RecordNotFound

    def perform
      cleanup_expired_exports
      cleanup_old_failed_exports
    end

    private

    def cleanup_expired_exports
      AccountExport.expired.find_each do |export|
        export.archive.purge if export.archive.attached?
        export.destroy
        Rails.logger.info("[ExportCleanup] Purged expired export ##{export.id}")
      end
    end

    def cleanup_old_failed_exports
      AccountExport.where(status: "failed")
        .where("created_at < ?", 1.day.ago)
        .find_each do |export|
          export.destroy
          Rails.logger.info("[ExportCleanup] Removed failed export ##{export.id}")
        end
    end
  end
end
