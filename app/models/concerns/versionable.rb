# Provides versioning functionality for ActiveRecord models
# Enables Claude-like artifact versioning where new versions can be created from any existing version
module Versionable
  extend ActiveSupport::Concern

  included do
    validates :version, presence: true, numericality: {greater_than: 0}
    before_validation :set_version, on: :create
  end

  # Calculate the next version number
  # If this is a child version, increment from the root's maximum version
  # If this is a root version, start at 1
  def next_version_number
    if parent_memory_id.present?
      # This is a new version of an existing memory
      root_memory.all_versions.maximum(:version).to_i + 1
    else
      # This is the first version
      1
    end
  end

  # Human-readable version label
  def version_label
    "v#{version}"
  end

  # Check if this memory has any versions (either parent or children)
  def has_versions?
    child_versions.any? || parent_memory.present?
  end

  private

  def set_version
    self.version ||= next_version_number
  end
end
