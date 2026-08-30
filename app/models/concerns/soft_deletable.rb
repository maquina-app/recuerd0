# Provides soft delete functionality for ActiveRecord models
module SoftDeletable
  extend ActiveSupport::Concern

  # How long a soft-deleted record stays recoverable. Surfaced verbatim in the
  # delete confirmation, so the number the user is promised is this number.
  RETENTION_DAYS = 30

  included do
    scope :deleted, -> { where.not(deleted_at: nil) }
    scope :not_deleted, -> { where(deleted_at: nil) }
    scope :deleted_ordered, -> { deleted.order(deleted_at: :desc) }
  end

  # Soft delete the record
  def soft_delete
    update_attribute(:deleted_at, Time.current)
  end

  # Restore a soft deleted record
  def restore
    restored = update_attribute(:deleted_at, nil)
    after_restore if respond_to?(:after_restore, true)
    restored
  end

  # Check if the record is soft deleted
  def deleted?
    deleted_at.present?
  end

  # Override destroy to perform soft delete
  def destroy
    if persisted? && !@performing_hard_delete
      soft_delete
    else
      super
    end
  end

  # Really destroy the record (bypass soft delete).
  #
  # This used to be `self.class.where(id: id).delete_all`, which issues a bare
  # DELETE and so skips every `dependent: :destroy` association. `memories`
  # references `workspaces` with no ON DELETE CASCADE and SQLite runs with
  # `PRAGMA foreign_keys = 1`, so "Delete permanently" raised
  # ActiveRecord::InvalidForeignKey — a 500 — for any workspace that actually
  # held memories. Every soft-deleted workspace in the seed data has zero
  # memories, which is why it never showed up.
  #
  # Routing through the real destroy runs the dependent callbacks; the flag is
  # what stops the override above from turning it back into a soft delete.
  def destroy!
    with_lock do
      @performing_hard_delete = true
      super
    ensure
      @performing_hard_delete = false
    end
  end

  # Calculate days until permanent deletion
  def days_until_permanent_deletion
    return nil unless deleted? && deleted_at.present?

    days_elapsed = (Date.current - deleted_at.to_date).to_i
    days_remaining = RETENTION_DAYS - days_elapsed
    (days_remaining > 0) ? days_remaining : 0
  end

  # Check if scheduled for permanent deletion
  def scheduled_for_permanent_deletion?
    deleted? && days_until_permanent_deletion == 0
  end
end
