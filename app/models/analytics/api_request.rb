module Analytics
  class ApiRequest < ApplicationRecord
    self.table_name = "analytics_api_requests"

    belongs_to :account, optional: true
    belongs_to :user, optional: true
    belongs_to :access_token, optional: true

    validates :http_method, :path, :status, presence: true
  end
end
