class CreateAnalyticsEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_events do |t|
      t.integer :account_id
      t.integer :user_id
      t.string :event_type, null: false
      t.string :resource_type
      t.integer :resource_id
      t.json :metadata
      t.string :ip_address
      t.string :user_agent
      t.datetime :created_at, null: false
    end

    add_index :analytics_events, [:account_id, :event_type, :created_at], name: "idx_analytics_events_account_type_time"
    add_index :analytics_events, [:resource_type, :resource_id], name: "idx_analytics_events_resource"
    add_index :analytics_events, [:user_id, :created_at], name: "idx_analytics_events_user_time"
  end
end
