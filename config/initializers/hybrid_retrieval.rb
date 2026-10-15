# Load the embedding model when the web server boots, so the first search that
# needs related memories doesn't pay the one-off model load (~250ms). Only the
# server process warms up; runners, consoles and tasks load it on first use.
Rails.application.config.after_initialize do
  next unless Rails.configuration.x.hybrid_retrieval && defined?(Rails::Server)

  EmbeddingProviders.application.embed("warm up")
rescue EmbeddingProviders::Error => error
  Rails.logger.warn("Hybrid retrieval warm-up skipped error=#{error.class}")
end
