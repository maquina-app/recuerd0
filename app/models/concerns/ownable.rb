# Who may delete, archive or purge a record: its creator, or an admin. A record
# with no recorded creator belongs to the account admin, which covers everything
# created before created_by existed and the seeded "My Workspace".
module Ownable
  extend ActiveSupport::Concern

  included do
    belongs_to :created_by, class_name: "User", optional: true
  end

  # Memory overrides this: a version belongs to whoever owns the memory.
  def ownership_record
    self
  end

  def owner_id
    ownership_record.created_by_id
  end

  def owned_by?(user)
    owner_id.present? && owner_id == user&.id
  end

  def manageable_by?(user)
    return false unless user

    user.admin? || owned_by?(user)
  end
end
