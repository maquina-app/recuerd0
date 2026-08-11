class MemoryEmbedding < ApplicationRecord
  class InvalidVector < StandardError; end

  belongs_to :memory

  validates :memory_id, uniqueness: true
  validates :model, :content_hash, :vector, presence: true

  def self.pack_vector(values, dimensions:)
    packed = validate_vector!(values, dimensions:).pack("e*")
    validate_vector!(packed.unpack("e*"), dimensions:)
    packed
  end

  def self.unpack_vector(bytes, dimensions:)
    expected_bytes = Integer(dimensions) * 4
    unless bytes&.bytesize == expected_bytes
      raise InvalidVector,
        "expected #{expected_bytes} vector bytes, got #{bytes&.bytesize || 0}"
    end

    validate_vector!(bytes.unpack("e*"), dimensions:)
  end

  def self.validate_vector!(values, dimensions:)
    vector = Array(values)
    expected_dimensions = Integer(dimensions)
    unless vector.length == expected_dimensions
      raise InvalidVector,
        "expected #{expected_dimensions} dimensions, got #{vector.length}"
    end

    vector.map do |value|
      number = Float(value)
      raise InvalidVector, "vector values must be finite" unless number.finite?

      number
    rescue ArgumentError, TypeError
      raise InvalidVector, "vector values must be numeric and finite"
    end
  end

  def vector_values(dimensions: Rails.configuration.x.hybrid_retrieval_dimensions)
    self.class.unpack_vector(vector, dimensions:)
  end
end
