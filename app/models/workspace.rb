class Workspace < ApplicationRecord
  include SoftDeletable
  include Archivable

  belongs_to :user
  has_many :memories, dependent: :destroy

  # Validations
  validates :name, presence: true, length: {maximum: 100}
  validates :description, length: {maximum: 500}, allow_blank: true

  # Scopes
  scope :ordered, -> { order(created_at: :desc) }
  scope :search, ->(query) { where("name ILIKE :query OR description ILIKE :query", query: "%#{query}%") if query.present? }
  scope :active, -> { not_archived.not_deleted }

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
end
