require "digest"

class FakeEmbeddingProvider
  attr_reader :model, :dimensions, :embedded_texts

  def initialize(model: "fake-embedding-model", dimensions: 3, vectors: {}, &embedding)
    @model = model
    @dimensions = dimensions
    @vectors = vectors
    @embedding = embedding
    @embedded_texts = []
  end

  def embed(text)
    @embedded_texts << text
    vector = if @embedding
      @embedding.call(text)
    elsif @vectors.key?(text)
      @vectors.fetch(text)
    else
      deterministic_vector(text)
    end
    vector.dup
  end

  private

  def deterministic_vector(text)
    bytes = Digest::SHA256.digest(text.to_s).bytes
    Array.new(dimensions) { |index| (bytes[index] + 1) / 256.0 }
  end
end

module HybridRetrievalTestHelper
  def with_hybrid_retrieval(enabled = true, provider: EmbeddingProviders.provider_override)
    previous_flag = Rails.configuration.x.hybrid_retrieval
    previous_provider = EmbeddingProviders.provider_override
    Rails.configuration.x.hybrid_retrieval = enabled
    EmbeddingProviders.provider_override = provider
    yield provider
  ensure
    Rails.configuration.x.hybrid_retrieval = previous_flag
    EmbeddingProviders.provider_override = previous_provider
  end

  def create_memory_embedding(memory, vector:, model: EmbeddingProviders.application.model)
    MemoryEmbedding.create!(
      memory_id: memory.root_memory.id,
      model: model,
      content_hash: Digest::SHA256.hexdigest("test-#{memory.id}-#{model}"),
      vector: MemoryEmbedding.pack_vector(
        vector,
        dimensions: EmbeddingProviders.application.dimensions
      )
    )
  end
end
