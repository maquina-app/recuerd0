module Accounts
  # Keeps the promise the Terms, the Privacy Policy and the "Deletes in N days"
  # badges make: 30 days after deletion, an account or workspace is gone for good.
  # Accounts first, since purging one takes its workspaces with it. One failure
  # must not keep the rest from being removed on time.
  class PurgeDeletedJob < ApplicationJob
    queue_as :default

    def perform
      purge(Account.past_retention, &:purge!)
      purge(Workspace.past_retention, &:destroy!)
    end

    private

    def purge(records, &removal)
      records.find_each do |record|
        removal.call(record)
        Rails.logger.info("[PurgeDeleted] Purged #{record.class.name} ##{record.id}")
      rescue => error
        Rails.logger.error("[PurgeDeleted] Could not purge #{record.class.name} ##{record.id}: #{error.class}: #{error.message}")
      end
    end
  end
end
