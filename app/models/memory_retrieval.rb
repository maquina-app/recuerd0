class MemoryRetrieval
  SEMANTIC_TOP_K = 50
  SUPERSEDED_DEMOTION = 0.5

  def initialize(relation:, provider: EmbeddingProviders.application)
    @relation = relation
    @provider = provider
  end

  def ranked_ids(query:)
    query_vector = MemoryEmbedding.validate_vector!(
      @provider.embed(query),
      dimensions: @provider.dimensions
    )
    metadata = relation_metadata

    candidates = MemoryEmbedding
      .where(
        model: @provider.model,
        memory_id: @relation.reorder(nil).select(:id)
      )
      .find_each
      .map do |embedding|
        vector = MemoryEmbedding.unpack_vector(
          embedding.vector,
          dimensions: @provider.dimensions
        )
        similarity = cosine_similarity(query_vector, vector)
        memory = metadata.fetch(embedding.memory_id)
        similarity *= SUPERSEDED_DEMOTION if superseded?(memory[:tags])

        [embedding.memory_id, similarity]
      end

    candidates.sort_by do |memory_id, similarity|
      memory = metadata.fetch(memory_id)
      [-similarity, -memory[:updated_at].to_f, -memory_id]
    end.first(SEMANTIC_TOP_K).map(&:first)
  end

  private

  def cosine_similarity(left, right)
    dot_product = 0.0
    left_norm = 0.0
    right_norm = 0.0

    left.zip(right).each do |left_value, right_value|
      dot_product += left_value * right_value
      left_norm += left_value * left_value
      right_norm += right_value * right_value
    end

    denominator = Math.sqrt(left_norm) * Math.sqrt(right_norm)
    denominator.zero? ? 0.0 : dot_product / denominator
  end

  def superseded?(tags)
    normalize_tags(tags).any? { |tag| tag.to_s.casecmp?("superseded") }
  end

  def normalize_tags(tags)
    values = case tags
    when Array
      tags
    when String
      JSON.parse(tags) unless tags.blank?
    end

    values.is_a?(Array) ? values : []
  rescue JSON::ParserError
    []
  end

  def relation_metadata
    @relation_metadata ||= @relation
      .reorder(nil)
      .pluck(:id, :updated_at, Arel.sql("CAST(memories.tags AS TEXT)"))
      .to_h do |id, updated_at, tags|
        [id, {updated_at: updated_at, tags: tags}]
      end
  end
end
