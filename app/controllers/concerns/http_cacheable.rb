module HttpCacheable
  extend ActiveSupport::Concern

  private

  # Wrapper for fresh_when ensuring private cache for authenticated content
  def fresh_when_private(record_or_options)
    options = normalize_cache_options(record_or_options)
    options[:cache_control] = {private: true}
    fresh_when(**options)
  end

  # Build composite ETag for collections with pagination
  def collection_cache_key(collection, pagy, *additional_keys)
    [
      collection.maximum(:updated_at)&.to_i,
      collection.count,
      pagy.page,
      *additional_keys
    ]
  end

  def normalize_cache_options(record_or_options)
    if record_or_options.is_a?(Hash)
      record_or_options
    else
      {etag: record_or_options, last_modified: record_or_options.try(:updated_at)}
    end
  end
end
