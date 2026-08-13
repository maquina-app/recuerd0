require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Recuerd0
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks rails_ext])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.yml")]

    config.active_storage.variant_processor = :disabled

    config.multi_tenant = ENV.fetch("MULTI_TENANT_ENABLED", "false") == "true"

    config.x.hybrid_retrieval = ENV.fetch("HYBRID_RETRIEVAL", "false") == "true"
    config.x.hybrid_retrieval_provider = ENV.fetch("HYBRID_RETRIEVAL_PROVIDER", "informers")
    config.x.hybrid_retrieval_model = ENV.fetch(
      "HYBRID_RETRIEVAL_MODEL",
      "sentence-transformers/all-MiniLM-L6-v2"
    )
    config.x.hybrid_retrieval_revision = ENV.fetch(
      "HYBRID_RETRIEVAL_REVISION",
      "1110a243fdf4706b3f48f1d95db1a4f5529b4d41"
    )
    config.x.hybrid_retrieval_dimensions = ENV.fetch("HYBRID_RETRIEVAL_DIMENSIONS", "384").to_i
    config.x.hybrid_retrieval_cache_dir = if Rails.env.production?
      Rails.root.join("storage", "informers")
    end

    config.exceptions_app = routes
  end
end
