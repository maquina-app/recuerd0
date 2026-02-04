class Pin < ApplicationRecord
  belongs_to :user
  belongs_to :pinnable, polymorphic: true

  # Validations
  validates :position, presence: true, numericality: {greater_than_or_equal_to: 0}
  validates :user_id, uniqueness: {
    scope: [:pinnable_type, :pinnable_id]
  }

  # Scopes
  scope :ordered, -> { order(:position, created_at: :desc) }
  scope :for_workspaces, -> { where(pinnable_type: "Workspace") }
  scope :for_memories, -> { where(pinnable_type: "Memory") }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  before_validation :set_position, on: :create
  after_destroy :reorder_positions

  private

  def set_position
    return if position.present?

    max_position = user.pins
      .where(pinnable_type: pinnable_type)
      .maximum(:position) || -1
    self.position = max_position + 1
  end

  def reorder_positions
    user.pins
      .where(pinnable_type: pinnable_type)
      .where("position > ?", position)
      .update_all("position = position - 1")
  end
end
