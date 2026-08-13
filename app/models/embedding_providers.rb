module EmbeddingProviders
  class Error < StandardError; end
  class ConfigurationError < Error; end

  REGISTRY = {
    "informers" => ->(**options) { InformersProvider.new(**options) }
  }.freeze

  class << self
    attr_accessor :provider_override

    def application
      provider_override || resolve(local_files_only: true)
    end

    def backfill
      provider_override || resolve(local_files_only: false)
    end

    private

    def resolve(local_files_only:)
      provider_name = Rails.configuration.x.hybrid_retrieval_provider.to_s
      factory = REGISTRY[provider_name]
      unless factory
        raise ConfigurationError, "Unknown hybrid retrieval provider: #{provider_name.inspect}"
      end

      factory.call(
        model: Rails.configuration.x.hybrid_retrieval_model,
        revision: Rails.configuration.x.hybrid_retrieval_revision,
        dimensions: Rails.configuration.x.hybrid_retrieval_dimensions,
        cache_dir: Rails.configuration.x.hybrid_retrieval_cache_dir,
        local_files_only: local_files_only
      )
    end
  end

  class InformersProvider
    @pipelines = {}
    @pipelines_mutex = Mutex.new

    class << self
      attr_reader :pipelines, :pipelines_mutex
    end

    attr_reader :model, :dimensions

    def initialize(model:, revision:, dimensions:, cache_dir:, local_files_only:)
      @model_name = model.to_s
      @revision = revision.to_s
      @model = "#{@model_name}@#{@revision}"
      @dimensions = Integer(dimensions)
      @cache_dir = cache_dir&.to_s
      @local_files_only = local_files_only
    end

    def embed(text)
      pipeline.call(text.to_s)
    rescue => error
      raise Error, "Informers could not load or run #{@model}: #{error.class}: #{error.message}"
    end

    private

    def pipeline
      key = [@model, @cache_dir, @local_files_only]
      self.class.pipelines_mutex.synchronize do
        self.class.pipelines[key] ||= ::Informers.pipeline(
          "embedding",
          @model_name,
          revision: @revision,
          cache_dir: @cache_dir,
          local_files_only: @local_files_only
        )
      end
    end
  end
end
