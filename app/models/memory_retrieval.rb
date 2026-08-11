class MemoryRetrieval
  SEMANTIC_TOP_K = 50
  RRF_K = 60
  HALF_LIFE_DAYS = 30
  DECAY_FLOOR = 0.25

  def initialize(relation:, provider: EmbeddingProviders.application, now: Time.current)
    @relation = relation
    @provider = provider
    @now = now
  end

  def ranked_ids(query:, mode:)
    case mode
    when "semantic"
      semantic_ids(query)
    when "hybrid", "hybrid_decay"
      lexical_ids = @relation.search(query).pluck(:id)
      semantic_ids = semantic_ids(query)
      scores = self.class.rrf_scores(lexical_ids, semantic_ids)
      scores = apply_decay(scores) if mode == "hybrid_decay"
      sort_scores(scores)
    else
      raise ArgumentError, "unsupported retrieval mode: #{mode.inspect}"
    end
  end

  def self.rrf_scores(*ranked_lists)
    ranked_lists.each_with_object(Hash.new(0.0)) do |ids, scores|
      ids.each_with_index do |id, index|
        scores[id] += 1.0 / (RRF_K + index + 1)
      end
    end
  end

  def self.decay_factor(category:, updated_at:, now: Time.current)
    return 1.0 unless category == Memory::DEFAULT_CATEGORY

    age_days = [((now - updated_at) / 1.day).to_f, 0.0].max
    [0.5**(age_days / HALF_LIFE_DAYS), DECAY_FLOOR].max
  end

  private

  def semantic_ids(query)
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
        [embedding.memory_id, cosine_similarity(query_vector, vector)]
      end

    candidates.sort_by do |memory_id, similarity|
      memory = metadata.fetch(memory_id)
      [-similarity, -memory[:updated_at].to_f, -memory_id]
    end.first(SEMANTIC_TOP_K).map(&:first)
  end

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

  def apply_decay(scores)
    metadata = relation_metadata
    scores.to_h do |memory_id, score|
      memory = metadata.fetch(memory_id)
      [
        memory_id,
        score * self.class.decay_factor(
          category: memory[:category],
          updated_at: memory[:updated_at],
          now: @now
        )
      ]
    end
  end

  def sort_scores(scores)
    metadata = relation_metadata
    scores.sort_by do |memory_id, score|
      memory = metadata.fetch(memory_id)
      [-score, -memory[:updated_at].to_f, -memory_id]
    end.map(&:first)
  end

  def relation_metadata
    @relation_metadata ||= @relation.reorder(nil).pluck(:id, :updated_at, :category).to_h do |row|
      [row[0], {updated_at: row[1], category: row[2]}]
    end
  end
end
