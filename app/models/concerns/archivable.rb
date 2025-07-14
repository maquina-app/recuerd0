# Provides archive functionality for ActiveRecord models
module Archivable
  extend ActiveSupport::Concern

  included do
    # Scopes
    scope :archived, -> { where.not(archived_at: nil) }
    scope :not_archived, -> { where(archived_at: nil) }
    scope :archived_ordered, -> { archived.order(archived_at: :desc) }
  end

  # Archive the record
  def archive
    update_column(:archived_at, Time.current)
  end

  # Unarchive the record
  def unarchive
    update_column(:archived_at, nil)
  end

  # Check if the record is archived
  def archived?
    archived_at.present?
  end

  # Toggle archive status
  def toggle_archive
    if archived?
      unarchive
    else
      archive
    end
  end
end
