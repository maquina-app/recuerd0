module Analytics
  module Trackable
    extend ActiveSupport::Concern

    included do
      before_action :set_request_start_time
      after_action :track_api_request, if: :api_request?
    end

    private

    def track_event(event_type, resource: nil, metadata: {})
      attributes = {
        account_id: Current.account&.id,
        user_id: Current.user&.id,
        event_type: event_type,
        resource_type: resource&.class&.name,
        resource_id: resource&.id,
        metadata: metadata.presence,
        ip_address: Analytics::IpAnonymizer.anonymize(request.remote_ip),
        user_agent: request.user_agent
      }

      Analytics::RecordEventJob.perform_later(attributes)
    end

    def track_api_request
      attributes = {
        account_id: Current.account&.id,
        user_id: Current.user&.id,
        access_token_id: current_access_token&.id,
        http_method: request.method,
        path: request.path,
        status: response.status,
        duration_ms: request_duration_ms,
        ip_address: Analytics::IpAnonymizer.anonymize(request.remote_ip),
        user_agent: request.user_agent
      }

      Analytics::RecordApiRequestJob.perform_later(attributes)
    end

    def set_request_start_time
      @_request_start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def request_duration_ms
      return nil unless @_request_start_time
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @_request_start_time
      (elapsed * 1000).round
    end
  end
end
