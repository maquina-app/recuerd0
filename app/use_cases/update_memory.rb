# Use Case: Update an existing memory and its content
# Handles memory attribute updates and content updates in a transaction
class UpdateMemory
  def self.call(memory, attributes = {})
    new(memory, attributes).call
  end

  def initialize(memory, attributes)
    @memory = memory
    @attributes = attributes
  end

  def call
    Memory.transaction do
      update_memory_attributes
      update_or_create_content
      memory
    end
  rescue ActiveRecord::RecordInvalid => e
    memory.errors.add(:base, e.message)
    memory
  end

  private

  attr_reader :memory, :attributes

  def update_memory_attributes
    memory_attrs = attributes.slice(:title, :tags, :source)
    memory.update!(memory_attrs) unless memory_attrs.empty?
  end

  def update_or_create_content
    # Get content from attributes - it may be a string key or symbol key
    content_body = attributes[:content] || attributes["content"] || ""

    if memory.content.present?
      # Force update even if value hasn't changed
      memory.content.update_column(:body, content_body)
    else
      memory.create_content!(body: content_body)
    end
  end
end
