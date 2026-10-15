require "digest"

module Embeddable
  extend ActiveSupport::Concern

  included do
    after_save_commit :rebuild_embedding_safely
    after_destroy_commit :refresh_embedding_after_destroy_safely
  end

  class_methods do
    # The semantic fallback every search surface shares: when keyword search
    # found fewer than MemoryRetrieval::RELATED_WHEN_FEWER_THAN hits, the roots
    # in this scope closest in meaning to the query, as MemoryRetrieval::Match.
    # Keyword hits are never reordered, and a model failure leaves the keyword
    # results standing rather than failing the search.
    def related_to(query, keyword_count:, excluding: [])
      return [] unless Rails.configuration.x.hybrid_retrieval
      return [] if keyword_count >= MemoryRetrieval::RELATED_WHEN_FEWER_THAN

      text = plain_query(query)
      return [] if text.length < Searchable::MIN_QUERY_LENGTH

      scored = MemoryRetrieval.new(relation: all).related(query: text, excluding: excluding)
      memories = where(id: scored.map(&:first)).index_by(&:id)
      scored.filter_map do |memory_id, similarity|
        MemoryRetrieval::Match.new(memory: memories[memory_id], similarity: similarity.round(3)) if memories[memory_id]
      end
    rescue EmbeddingProviders::Error, MemoryEmbedding::InvalidVector => error
      Rails.logger.error("Related memories unavailable error=#{error.class}")
      []
    end
  end

  def rebuild_embedding(provider: nil)
    return :disabled unless Rails.configuration.x.hybrid_retrieval

    provider ||= EmbeddingProviders.application
    root = root_memory
    newest = root.child_versions.includes(:content).order(version: :desc).first || root
    text = newest.title.to_s + "\n\n" + newest.content&.body&.content.to_s
    content_hash = Digest::SHA256.hexdigest(text)

    existing = MemoryEmbedding.find_by(memory_id: root.id)
    if existing&.content_hash == content_hash && existing.model == provider.model
      return :unchanged
    end

    packed_vector = MemoryEmbedding.pack_vector(
      provider.embed(text),
      dimensions: provider.dimensions
    )

    MemoryEmbedding.transaction do
      MemoryEmbedding.where(memory_id: root.id).delete_all
      MemoryEmbedding.create!(
        memory_id: root.id,
        model: provider.model,
        content_hash: content_hash,
        vector: packed_vector
      )
    end

    :embedded
  end

  def rebuild_embedding_safely
    return unless Rails.configuration.x.hybrid_retrieval

    root_id = root_memory.id
    provider = EmbeddingProviders.application
    provider_model = provider.model
    rebuild_embedding(provider: provider)
  rescue => error
    discard_stale_embedding(root_id, error, model: provider_model)
  end

  private

  def refresh_embedding_after_destroy_safely
    return unless Rails.configuration.x.hybrid_retrieval

    root_id = root_version? ? id : parent_memory_id
    if root_version?
      MemoryEmbedding.where(memory_id: root_id).delete_all
    elsif (root = self.class.find_by(id: root_id))
      provider = EmbeddingProviders.application
      provider_model = provider.model
      root.rebuild_embedding(provider: provider)
    end
  rescue => error
    discard_stale_embedding(root_id, error, model: provider_model)
  end

  def discard_stale_embedding(root_id, error, model: nil)
    begin
      MemoryEmbedding.where(memory_id: root_id).delete_all if root_id
    rescue
      # The original maintenance error is the actionable failure. A missing or
      # unavailable embedding table must not leak out of an after-commit callback.
    end

    model ||= Rails.configuration.x.hybrid_retrieval_model
    Rails.logger.error(
      "Hybrid retrieval embedding failed root_id=#{root_id.inspect} " \
        "model=#{model.inspect} error=#{error.class}"
    )
    nil
  end
end
