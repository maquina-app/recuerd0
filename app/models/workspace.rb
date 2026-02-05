class Workspace < ApplicationRecord
  include SoftDeletable
  include Archivable
  include Pinnable

  belongs_to :account
  has_many :memories, dependent: :destroy

  # Validations
  validates :name, presence: true, length: {maximum: 100}
  validates :description, length: {maximum: 500}, allow_blank: true

  # Callbacks to unpin when archiving or soft deleting
  after_update :unpin_if_inactive, if: -> { saved_change_to_archived_at? || saved_change_to_deleted_at? }

  # Scopes
  scope :ordered, -> { order(created_at: :desc) }
  scope :search, ->(query) {
    if query.present?
      where("LOWER(name) LIKE LOWER(:query) OR LOWER(description) LIKE LOWER(:query)",
        query: "%#{sanitize_sql_like(query)}%")
    end
  }
  scope :active, -> { not_archived.not_deleted }
  scope :archived_ordered, -> { archived.not_deleted.order(archived_at: :desc) }

  # Additional scopes that consider pinning
  scope :ordered_with_pins_first, ->(user) {
    left_joins(:pins)
      .where(pins: {user_id: [user.id, nil]})
      .order(
        Arel.sql("CASE WHEN pins.id IS NOT NULL THEN 0 ELSE 1 END"),
        Arel.sql("pins.position ASC NULLS LAST"),
        Arel.sql("workspaces.updated_at DESC")
      )
      .distinct
  }

  # Instance methods
  def last_activity
    memories.maximum(:created_at) || created_at
  end

  # Check if workspace can be used (not deleted or archived)
  def active?
    !deleted? && !archived?
  end

  # Status for display
  def status
    return :deleted if deleted?
    return :archived if archived?
    :active
  end

  private

  # Unpin from all users when workspace becomes inactive
  def unpin_if_inactive
    return if active?

    pins.destroy_all
  end

  # Called by SoftDeletable#restore to also unarchive the workspace
  def after_restore
    unarchive if archived?
  end
end
