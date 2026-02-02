# Use Case: Create a new memory within a workspace
# Handles memory creation with initial content
class CreateMemory
  def self.call(workspace, attributes = {})
    new(workspace, attributes).call
  end

  def initialize(workspace, attributes)
    @workspace = workspace
    @attributes = attributes
  end

  def call
    memory = @workspace.memories.build(memory_attributes)

    if memory.save
      create_content(memory)
      memory
    else
      memory
    end
  end

  private

  attr_reader :workspace, :attributes

  def memory_attributes
    attributes.slice(:title, :tags, :source)
  end

  def create_content(memory)
    content_body = attributes[:content].presence || ""
    memory.create_content(body: content_body)
  end
end
