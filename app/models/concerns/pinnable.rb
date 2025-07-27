module Pinnable
  extend ActiveSupport::Concern

  included do
    has_many :pins, as: :pinnable, dependent: :destroy

    scope :pinned_by, ->(user) {
      return none unless user

      joins(:pins)
        .where(pins: {user_id: user.id})
        .order("pins.position ASC, pins.created_at DESC")
    }

    scope :not_pinned_by, ->(user) {
      return all unless user

      where.not(id: pinned_by(user).select(:id))
    }
  end

  def pinned_by?(user)
    return false unless user
    pins.exists?(user: user)
  end

  def pin_for(user)
    return nil unless user
    pins.find_by(user: user)
  end

  def pin!(user)
    return nil unless user
    return pin_for(user) if pinned_by?(user)

    # Check if the item can be pinned (must be active)
    if respond_to?(:active?) && !active?
      raise ActiveRecord::RecordInvalid.new(self).tap do |e|
        errors.add(:base, "Cannot pin inactive items")
        e.record = self
      end
    end

    pins.create!(user: user)
  end

  def unpin!(user)
    return false unless user
    pin = pin_for(user)
    return false unless pin

    pin.destroy!
    true
  end

  def toggle_pin_for!(user)
    if pinned_by?(user)
      unpin!(user)
      false
    else
      pin!(user)
      true
    end
  end

  def pin_position_for(user)
    pin_for(user)&.position
  end
end
