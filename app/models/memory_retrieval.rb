class MemoryRetrieval
  SEMANTIC_TOP_K = 50
  OBSOLETE_DEMOTION = 0.5

  # Keyword search stays first everywhere; embeddings only fill in when it
  # comes up nearly empty. Fusing the two lists demoted exact matches on the
  # retrieval bench (D022), and a third of production searches returned
  # nothing, so the vectors earn their place as a fallback, not a blend.
  RELATED_WHEN_FEWER_THAN = 3
  # MiniLM cosine: gibberish peaked at 0.28 and unrelated prose at 0.22 on the
  # production corpus, while plausible matches started around 0.33.
  RELATED_FLOOR = 0.33
  RELATED_LIMIT = 5

  Match = Data.define(:memory, :similarity)

  def initialize(relation:, provider: EmbeddingProviders.application)
    @relation = relation
    @provider = provider
  end

  def ranked_ids(query:)
    scored(query).first(SEMANTIC_TOP_K).map(&:first)
  end

  # [memory_id, similarity] pairs at or above the floor, most similar first,
  # skipping what keyword search already returned.
  def related(query:, excluding: [])
    excluded = excluding.to_set

    scored(query)
      .select { |memory_id, _| excluded.exclude?(memory_id) }
      .take_while { |_, similarity| similarity >= RELATED_FLOOR }
      .first(RELATED_LIMIT)
  end

  private

  # Every embedded root in the relation, scored against the query, most similar
  # first. Vectors were validated when written, so they are unpacked without
  # per-element checks; a corrupt row scores as non-finite and is dropped.
  def scored(query)
    query_vector = MemoryEmbedding.validate_vector!(
      @provider.embed(query),
      dimensions: @provider.dimensions
    )
    query_norm = Math.sqrt(query_vector.sum { |value| value * value })
    return [] if query_norm.zero?

    metadata = relation_metadata
    expected_bytes = @provider.dimensions * 4

    candidates = MemoryEmbedding
      .where(model: @provider.model, memory_id: @relation.reorder(nil).select(:id))
      .pluck(:memory_id, :vector)
      .filter_map do |memory_id, bytes|
        next unless bytes&.bytesize == expected_bytes

        similarity = cosine_similarity(query_vector, query_norm, bytes.unpack("e*"))
        next unless similarity.finite?

        similarity *= OBSOLETE_DEMOTION if obsolete?(metadata.fetch(memory_id)[:tags])
        [memory_id, similarity]
      end

    candidates.sort_by do |memory_id, similarity|
      [-similarity, -metadata.fetch(memory_id)[:updated_at].to_f, -memory_id]
    end
  end

  # One pass, no intermediate arrays: this loop runs once per embedded memory
  # on every semantic query.
  def cosine_similarity(query_vector, query_norm, vector)
    dot_product = 0.0
    norm = 0.0
    index = 0
    while index < vector.length
      value = vector[index]
      dot_product += query_vector[index] * value
      norm += value * value
      index += 1
    end

    norm.zero? ? 0.0 : dot_product / (query_norm * Math.sqrt(norm))
  end

  # Obsolete rows only reach here when the caller passed include=obsolete;
  # when they do, they rank below an equally similar current memory.
  def obsolete?(tags)
    normalize_tags(tags).any? { |tag| Memory::OBSOLETE_TAGS.include?(tag.to_s.downcase) }
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
