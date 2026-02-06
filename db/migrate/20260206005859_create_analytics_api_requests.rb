class CreateAnalyticsApiRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_api_requests do |t|
      t.integer :account_id
      t.integer :user_id
      t.integer :access_token_id
      t.string :http_method, null: false
      t.string :path, null: false
      t.integer :status, null: false
      t.integer :duration_ms
      t.string :ip_address
      t.string :user_agent
      t.datetime :created_at, null: false
    end

    add_index :analytics_api_requests, [:account_id, :created_at], name: "idx_analytics_api_requests_account_time"
    add_index :analytics_api_requests, [:access_token_id, :created_at], name: "idx_analytics_api_requests_token_time"
    add_index :analytics_api_requests, [:path, :http_method, :created_at], name: "idx_analytics_api_requests_endpoint_time"
  end
end
