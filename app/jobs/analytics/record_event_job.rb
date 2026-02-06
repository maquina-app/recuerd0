module Analytics
  class RecordEventJob < ApplicationJob
    queue_as :default

    def perform(attributes)
      Analytics::Event.create!(attributes)
    rescue => e
      Rails.logger.warn("[Analytics] Failed to record event: #{e.class}: #{e.message}")
    end
  end
end
