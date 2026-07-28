require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  config.x.app_base_url = ENV.fetch("APP_BASE_URL") { "https://#{ENV.fetch("APP_HOST", "recuerd0.ai")}" }

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = {"cache-control" => "public, max-age=#{1.year.to_i}"}

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # This drives URL generation, but it does NOT mark cookies `secure` — only
  # ActionDispatch::SSL, inserted by force_ssl below, does that.
  config.assume_ssl = true

  # force_ssl is what marks the session cookie `secure` and sends HSTS; without
  # it the session cookie went out unmarked and no HSTS header was sent at all.
  # It inserts no redirect here: assume_ssl sets X-Forwarded-Proto on EVERY
  # request, so request.ssl? is already true when the middleware runs.
  config.force_ssl = true
  config.ssl_options = {
    hsts: {expires: 2.years, subdomains: true, preload: true},
    # Belt and braces: if assume_ssl above were ever removed, a plain-HTTP /up
    # would start getting 301s and kamal-proxy would read the container as
    # unhealthy, failing deploys for a reason that looks nothing like this.
    redirect: {exclude: ->(request) { request.path == "/up" }}
  }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = {database: {writing: :queue}}

  # Raise delivery errors so failed emails are visible in logs.
  config.action_mailer.raise_delivery_errors = true

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {host: ENV.fetch("APP_HOST", "recuerd0.ai")}

  # Outgoing SMTP server configured via environment variables.
  config.action_mailer.smtp_settings = {
    user_name: ENV["SMTP_USER_NAME"],
    password: ENV["SMTP_PASSWORD"],
    address: ENV.fetch("SMTP_ADDRESS", "smtp.example.com"),
    port: ENV.fetch("SMTP_PORT", 587).to_i,
    authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection. Allowed hosts come from APP_HOSTS
  # (set in config/deploy.production.yml). If unset — e.g. a local production
  # console — host authorization stays off rather than rejecting everything.
  if (app_hosts = ENV["APP_HOSTS"]).present?
    config.hosts = app_hosts.split(",").map(&:strip).reject(&:blank?)
    # Skip host authorization for the Kamal health check (hits the container directly).
    config.host_authorization = {exclude: ->(request) { request.path == "/up" }}
  end
end
