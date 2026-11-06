# Account#purge! used to leave analytics behind, including search text, although the
# Privacy Policy promises a deleted account is permanently removed. Clear what the
# accounts already purged left.
class RemoveAnalyticsOfPurgedAccounts < ActiveRecord::Migration[8.0]
  def up
    %w[analytics_events analytics_api_requests].each do |table|
      execute "DELETE FROM #{table} WHERE account_id IS NOT NULL AND account_id NOT IN (SELECT id FROM accounts)"
    end
  end

  def down
    # The rows are gone, and they weren't meant to exist.
  end
end
