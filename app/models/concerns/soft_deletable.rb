# frozen_string_literal: true

# Provides soft delete functionality for ActiveRecord models
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    # Default scope excludes soft deleted records
    default_scope { where(deleted_at: nil) }

    # Scopes
    scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
    scope :with_deleted, -> { unscoped }
    scope :only_deleted, -> { unscoped.where.not(deleted_at: nil) }
    scope :not_deleted, -> { where(deleted_at: nil) }
  end

  # Soft delete the record
  def soft_delete
    update_column(:deleted_at, Time.current)
  end

  # Restore a soft deleted record
  def restore
    update_columns(deleted_at: nil, archived_at: nil)
  end

  # Check if the record is soft deleted
  def deleted?
    deleted_at.present?
  end

  # Override destroy to perform soft delete
  def destroy
    if persisted?
      soft_delete
    else
      super
    end
  end

  # Really destroy the record (bypass soft delete)
  def destroy!
    with_lock do
      self.class.unscoped.where(id: id).delete_all
    end
  end
end
