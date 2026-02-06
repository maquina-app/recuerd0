require "test_helper"

class Analytics::RecordEventJobTest < ActiveJob::TestCase
  test "creates an Analytics::Event record with correct attributes" do
    attributes = {
      event_type: "memory.view",
      account_id: accounts(:one).id,
      user_id: users(:one).id,
      resource_type: "Memory",
      resource_id: memories(:one).id,
      ip_address: "192.168.1.0",
      user_agent: "Mozilla/5.0",
      created_at: Time.current
    }

    assert_difference "Analytics::Event.count", 1 do
      Analytics::RecordEventJob.perform_now(attributes)
    end

    event = Analytics::Event.last
    assert_equal "memory.view", event.event_type
    assert_equal accounts(:one).id, event.account_id
    assert_equal "Memory", event.resource_type
  end

  test "silently discards invalid records without raising" do
    assert_nothing_raised do
      Analytics::RecordEventJob.perform_now({event_type: nil, created_at: Time.current})
    end

    assert_no_difference "Analytics::Event.count" do
      Analytics::RecordEventJob.perform_now({event_type: nil, created_at: Time.current})
    end
  end
end
