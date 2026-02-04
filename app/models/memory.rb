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

  def self.create_with_content(workspace, attributes)
    memory = workspace.memories.build(attributes.slice(:title, :tags, :source))

    transaction do
      memory.save!
      memory.create_content!(body: attributes[:content].presence || "")
    end

    memory
  rescue ActiveRecord::RecordInvalid
    memory
  end

  def update_with_content(attributes)
    transaction do
      update!(attributes.slice(:title, :tags, :source))

      content_body = attributes[:content] || ""
      if content
        content.update!(body: content_body)
      else
        create_content!(body: content_body)
      end
    end

    self
  rescue ActiveRecord::RecordInvalid
    self
  end

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

  def create_version!(attributes = {})
    root = root_memory

    new_version = root.child_versions.build(
      workspace: root.workspace,
      title: attributes[:title] || title,
      tags: attributes[:tags] || tags,
      source: attributes[:source] || source
    )

    transaction do
      new_version.save!
      new_version.create_content!(body: attributes[:content] || content&.body || "")
    end

    new_version
  rescue ActiveRecord::RecordInvalid
    new_version
  end

  # Display title with fallback for untitled memories
  def display_title
    title.presence || I18n.t("models.memory.untitled")
  end
end
