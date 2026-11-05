module Accounts
  # The end of the 30-day grace period the Terms promise. One failure must not
  # keep the rest of the accounts from being removed on time.
  class PurgeDeletedJob < ApplicationJob
    queue_as :default

    def perform
      Account.past_retention.find_each do |account|
        account.purge!
        Rails.logger.info("[PurgeDeleted] Purged account ##{account.id}")
      rescue => error
        Rails.logger.error("[PurgeDeleted] Could not purge account ##{account.id}: #{error.class}: #{error.message}")
      end
    end
  end
end
