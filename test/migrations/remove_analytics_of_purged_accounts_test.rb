require "test_helper"
require Rails.root.join("db/migrate/20261106000001_remove_analytics_of_purged_accounts")

class RemoveAnalyticsOfPurgedAccountsTest < ActiveSupport::TestCase
  test "removes rows for accounts that are gone, keeps the rest, and is idempotent" do
    gone = Account.maximum(:id) + 1000
    Analytics::Event.create!(account_id: gone, event_type: "search.query", metadata: {query: "their secret"})
    Analytics::ApiRequest.create!(account_id: gone, http_method: "GET", path: "/search.json", status: 200)
    live_event = Analytics::Event.create!(account: accounts(:one), event_type: "search.query")
    live_request = Analytics::ApiRequest.create!(account: accounts(:one), http_method: "GET", path: "/search.json", status: 200)
    no_account = Analytics::Event.create!(event_type: "auth.token_failed")

    migration = RemoveAnalyticsOfPurgedAccounts.new
    migration.up

    assert_not Analytics::Event.exists?(account_id: gone)
    assert_not Analytics::ApiRequest.exists?(account_id: gone)
    assert Analytics::Event.exists?(live_event.id)
    assert Analytics::ApiRequest.exists?(live_request.id)
    assert Analytics::Event.exists?(no_account.id)

    assert_nothing_raised { migration.up }
  end
end
