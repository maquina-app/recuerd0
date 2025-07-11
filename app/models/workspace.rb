class Workspace < ApplicationRecord
  belongs_to :user
  has_many :memories, dependent: :destroy

  # Validations
  validates :name, presence: true, length: {maximum: 100}
  validates :description, length: {maximum: 500}, allow_blank: true

  # Scopes
  scope :ordered, -> { order(created_at: :desc) }
  scope :search, ->(query) { where("name ILIKE :query OR description ILIKE :query", query: "%#{query}%") if query.present? }

  # Instance methods
  def memories_count
    memories.count
  end

  def last_activity
    memories.maximum(:created_at) || created_at
  end
end
