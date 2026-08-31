module Pinnable
  extend ActiveSupport::Concern

  included do
    has_many :pins, as: :pinnable, dependent: :destroy

    scope :pinned_by, ->(user) {
      return none unless user

      joins(:pins)
        .where(pins: {user_id: user.id})
        .order(Arel.sql("pins.position ASC, pins.created_at DESC"))
    }

    scope :not_pinned_by, ->(user) {
      return all unless user

      where.not(id: pinned_by(user).select(:id))
    }
  end

  # The record a pin actually attaches to. Defaults to self; Memory overrides
  # it to the root, so a pin follows the memory across versions instead of
  # freezing on the version that happened to be on screen.
  def pin_target
    self
  end

  def pinned_by?(user)
    return false unless user

    target = pin_target
    if target.equal?(self) && pins.loaded?
      pins.any? { |p| p.user_id == user.id }
    else
      target.pins.exists?(user: user)
    end
  end

  def pin_for(user)
    return nil unless user
    pin_target.pins.find_by(user: user)
  end

  # `origin` records who placed the pin. A user-origin pin is one the person
  # chose and it spends their PIN_LIMIT budget; a system-origin pin is one the
  # app placed for them and it does not — so a teammate creating a workspace
  # never eats someone else's budget, and a user at the cap still receives it.
  #
  # Idempotent, and deliberately origin-preserving: a memory a person pinned
  # themselves is never downgraded to a system pin, and a system pin they kept
  # is never upgraded.
  def pin!(user, origin: "user")
    return nil unless user
    return pin_for(user) if pinned_by?(user)

    # Check if the item can be pinned (must be active)
    if respond_to?(:active?) && !active?
      errors.add(:base, I18n.t("models.pinnable.inactive"))
      raise ActiveRecord::RecordInvalid.new(self)
    end

    if origin == "user" && !user.can_pin_more?
      errors.add(:base, I18n.t("models.pinnable.limit_reached", limit: User::PIN_LIMIT))
      raise ActiveRecord::RecordInvalid.new(self)
    end

    pin_target.pins.create!(user: user, origin: origin)
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

  # "user", "system", or nil when unpinned. Reads the loaded association on
  # the same fast path pinned_by? uses, so a preloaded list page spends no
  # extra query per row.
  def pin_origin_for(user)
    return nil unless user

    target = pin_target
    if target.equal?(self) && pins.loaded?
      pins.find { |p| p.user_id == user.id }&.origin
    else
      target.pins.find_by(user: user)&.origin
    end
  end

  def pin_position_for(user)
    pin_for(user)&.position
  end
end
