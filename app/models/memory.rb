class Memory < ApplicationRecord
  include Pinnable
  include Searchable

  belongs_to :workspace, touch: true, counter_cache: true
  belongs_to :parent_memory, class_name: "Memory", optional: true
  has_one :content, dependent: :destroy
  has_many :child_versions, class_name: "Memory", foreign_key: "parent_memory_id", dependent: :destroy

  # Serialize tags as an array - Rails 7+ syntax
  serialize :tags, coder: JSON, type: Array

  # Inherit workspace lifecycle state
  delegate :archived?, :deleted?, :active?, to: :workspace

  # Scopes
  scope :latest_versions, -> { where(parent_memory_id: nil) }
  scope :versions_of, ->(memory) { where(parent_memory_id: memory.id) }

  # Validations
  validates :title, length: {maximum: 255}
  validates :version, presence: true, numericality: {greater_than: 0}

  # Callbacks
  before_validation :set_version, on: :create

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

  # Check if this is the root version (no parent)
  def root_version?
    parent_memory_id.nil?
  end

  # Get the root memory (parent of all versions)
  def root_memory
    parent_memory_id.present? ? parent_memory : self
  end

  # Get all versions of this memory (including self if root)
  def all_versions
    if root_version?
      Memory.where(
        "(id = ? OR parent_memory_id = ?)",
        id, id
      ).order(:version)
    else
      parent_memory.all_versions
    end
  end

  # Returns the latest (highest version number) version of this memory
  def current_version
    if root_version?
      child_versions.order(version: :desc).first || self
    else
      root_memory.current_version
    end
  end

  # Check if this is the current (latest) version
  def current_version?
    self == root_memory.current_version
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

  # Human-readable version label
  def version_label
    "v#{version}"
  end

  # Check if this memory has any versions (either parent or children)
  def has_versions?
    child_versions.any? || parent_memory.present?
  end

  # Consolidate versions: keep this version and destroy all others
  def consolidate_versions!
    transaction do
      all_versions.where.not(id: id).destroy_all
      update!(parent_memory_id: nil, version: 1) if parent_memory_id.present?
    end
  end

  # Display title with fallback for untitled memories
  def display_title
    title.presence || I18n.t("models.memory.untitled")
  end

  private

  def set_version
    self.version = next_version_number
  end

  def next_version_number
    if parent_memory_id.present?
      root_memory.all_versions.maximum(:version).to_i + 1
    else
      1
    end
  end
end
