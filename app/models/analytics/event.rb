module Analytics
  class Event < ApplicationRecord
    self.table_name = "analytics_events"

    belongs_to :account, optional: true
    belongs_to :user, optional: true
    belongs_to :resource, polymorphic: true, optional: true

    validates :event_type, presence: true
  end
end
