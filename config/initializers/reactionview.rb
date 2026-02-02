# frozen_string_literal: true

if defined?(ReActionView)
  ReActionView.configure do |config|
    # Intercept .html.erb templates and process them with `Herb::Engine` for enhanced features
    config.intercept_erb = false # true

    # Enable debug mode in development (adds debug attributes to HTML)
    config.debug_mode = false # Rails.env.development?
  end
end
