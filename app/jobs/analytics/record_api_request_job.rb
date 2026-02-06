module Analytics
  class RecordApiRequestJob < ApplicationJob
    queue_as :default

    def perform(attributes)
      Analytics::ApiRequest.create!(attributes)
    rescue => e
      Rails.logger.warn("[Analytics] Failed to record API request: #{e.class}: #{e.message}")
    end
  end
end
