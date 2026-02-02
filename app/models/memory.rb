class Memory < ApplicationRecord
  include Pinnable
  include Versionable

  belongs_to :workspace, touch: true, counter_cache: true
  belongs_to :parent_memory, class_name: "Memory", optional: true
  has_one :content, dependent: :destroy
  has_many :child_versions, class_name: "Memory", foreign_key: "parent_memory_id", dependent: :destroy

  # Serialize tags as an array - Rails 7+ syntax
  serialize :tags, coder: JSON, type: Array

  # Inherit workspace lifecycle state
  delegate :archived?, :deleted?, :active?, to: :workspace

  # Version scopes
  scope :latest_versions, -> { where(parent_memory_id: nil) }
  scope :versions_of, ->(memory) { where(parent_memory_id: memory.id) }

  validates :title, length: {maximum: 255}

  after_create :create_default_content

  # Override pinning to respect workspace state
  def can_be_pinned?
    workspace.active?
  end

  # Check if this is the latest/root version
  def latest_version?
    parent_memory_id.nil?
  end

  # Get the root memory (parent of all versions)
  def root_memory
    parent_memory_id.present? ? parent_memory : self
  end

  # Get all versions of this memory (including self if root)
  def all_versions
    if latest_version?
      Memory.where(
        "(id = ? OR parent_memory_id = ?)",
        id, id
      ).order(:version)
    else
      parent_memory.all_versions
    end
  end

  # Create a new version from this memory
  def create_version!(attributes = {})
    CreateMemoryVersion.call(self, attributes)
  end

  # Display title with fallback for untitled memories
  def display_title
    title.presence || "Untitled Memory"
  end

  private

  def create_default_content
    create_content(body: "")
  end
end
