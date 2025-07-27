class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  has_many :workspaces, dependent: :destroy

  # Pin associations
  has_many :pins, dependent: :destroy
  has_many :pinned_workspaces,
    -> { joins(:pins).merge(Workspace.active).order("pins.position ASC") },
    through: :pins,
    source: :pinnable,
    source_type: "Workspace"
  has_many :pinned_memories,
    -> { joins(:pins).order("pins.position ASC") },
    through: :pins,
    source: :pinnable,
    source_type: "Memory"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Helper methods
  def pinned_items_count
    pins.count
  end

  def can_pin_more?(limit = 10)
    pinned_items_count < limit
  end

  def reorder_pins!(pinnable_type, new_order)
    pins.where(pinnable_type: pinnable_type).each do |pin|
      new_position = new_order.index(pin.pinnable_id)
      pin.update!(position: new_position) if new_position
    end
  end
end
