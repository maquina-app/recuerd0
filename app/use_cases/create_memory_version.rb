# Use Case: Create a new version of an existing memory
# Handles Claude-like artifact versioning where you can branch from any version
class CreateMemoryVersion
  def self.call(original_memory, attributes = {})
    new(original_memory, attributes).call
  end

  def initialize(original_memory, attributes)
    @original_memory = original_memory
    @attributes = attributes
  end

  def call
    root_memory = @original_memory.root_memory

    new_version = root_memory.child_versions.build(
      workspace: root_memory.workspace,
      title: attributes[:title] || original_memory.title,
      tags: attributes[:tags] || original_memory.tags,
      source: attributes[:source] || original_memory.source
    )

    if new_version.save
      create_content(new_version)
      new_version
    else
      new_version
    end
  end

  private

  attr_reader :original_memory, :attributes

  def create_content(memory)
    original_content = original_memory.content&.body || ""
    new_content = attributes[:content] || original_content
    memory.create_content(body: new_content)
  end
end
