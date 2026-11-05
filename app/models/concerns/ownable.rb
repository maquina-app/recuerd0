# Who answers for a record: its owner, or an admin. It starts as whoever created it
# and can be passed on, while created_by keeps saying who wrote it. A record with no
# owner belongs to the account admin, which covers everything older than these columns
# and the seeded "My Workspace".
module Ownable
  extend ActiveSupport::Concern

  included do
    belongs_to :created_by, class_name: "User", optional: true
    belongs_to :owner, class_name: "User", optional: true

    before_create :start_owned_by_creator

    scope :owned_by, ->(user) { where(owner_id: user.admin? ? [user.id, nil] : user.id) }
  end

  # Memory overrides this: a version belongs to whoever owns the memory.
  def ownership_record
    self
  end

  def owned_by?(user)
    current_owner_id = ownership_record.owner_id

    current_owner_id.present? && current_owner_id == user&.id
  end

  def manageable_by?(user)
    return false unless user

    user.admin? || owned_by?(user)
  end

  # An admin takes first and passes as the owner, so nobody is handed something by
  # someone who never held it.
  def ownership_passable_by?(user, to:)
    owned_by?(user) || (user&.admin? && to == user)
  end

  # No touch: this changes who answers for it, not what it says, so it should not
  # jump to the top of anything sorted by recent activity.
  def pass_ownership_to(user)
    ownership_record.update_column(:owner_id, user.id)
  end

  private

  def start_owned_by_creator
    self.owner ||= created_by if ownership_record == self
  end
end
