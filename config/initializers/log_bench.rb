# config/initializers/log_bench.rb
if defined?(LogBench)
  LogBench.setup do |config|
    # Enable/disable LogBench (default: true in development, false elsewhere)
    config.enabled = Rails.env.development? # or any other condition

    # Disable automatic lograge configuration (if you want to configure lograge manually)
    # config.configure_lograge_automatically = false  # (default: true)

    # Customize initialization message
    # config.show_init_message = :min # :full, :min, or :none (default: :full)

    # Specify which controllers to inject request_id tracking
    # config.base_controller_classes = %w[CustomBaseController] # (default: %w[ApplicationController, ActionController::Base])
  end
end
