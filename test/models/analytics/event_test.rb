require "test_helper"

class Analytics::EventTest < ActiveSupport::TestCase
  test "validates presence of event_type" do
    event = Analytics::Event.new(event_type: nil)
    assert_not event.valid?
    assert_includes event.errors[:event_type], "can't be blank"
  end

  test "creates event with valid attributes" do
    event = Analytics::Event.create!(
      event_type: "memory.view",
      account_id: accounts(:one).id,
      user_id: users(:one).id,
      resource_type: "Memory",
      resource_id: memories(:one).id,
      ip_address: "192.168.1.0",
      user_agent: "Mozilla/5.0",
      created_at: Time.current
    )
    assert event.persisted?
  end

  test "stores and retrieves JSON metadata" do
    event = Analytics::Event.create!(
      event_type: "search.query",
      metadata: {query: "test search", results_count: 5, workspace_id: 1},
      created_at: Time.current
    )
    event.reload

    assert_equal "test search", event.metadata["query"]
    assert_equal 5, event.metadata["results_count"]
    assert_equal 1, event.metadata["workspace_id"]
  end
end
