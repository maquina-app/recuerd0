class MemoryLink < ApplicationRecord
  belongs_to :from_memory, class_name: "Memory"
  belongs_to :to_memory, class_name: "Memory"
  # Nullable on purpose: a link with no recorded creator belongs to the account admin.
  belongs_to :created_by, class_name: "User", optional: true

  before_validation :point_at_roots, :normalize_order
  validate :different_memories
  validate :same_account
  validates :from_memory_id, uniqueness: {scope: :to_memory_id}

  scope :involving, ->(memory) {
    where(from_memory_id: memory.id).or(where(to_memory_id: memory.id))
  }

  def other_side(memory)
    (from_memory_id == memory.id) ? to_memory : from_memory
  end

  def other_side_id(memory)
    (from_memory_id == memory.id) ? to_memory_id : from_memory_id
  end

  # Who may remove this link: an admin, or whoever created it.
  def manageable_by?(user)
    return false unless user

    user.admin? || (created_by_id.present? && created_by_id == user.id)
  end

  private

  # A link joins memories, not versions: every surface reads links off the root.
  def point_at_roots
    self.from_memory = from_memory.root_memory if from_memory&.parent_memory_id
    self.to_memory = to_memory.root_memory if to_memory&.parent_memory_id
  end

  def normalize_order
    return if from_memory_id.blank? || to_memory_id.blank?
    if to_memory_id < from_memory_id
      self.from_memory_id, self.to_memory_id = to_memory_id, from_memory_id
    end
  end

  def different_memories
    errors.add(:base, "cannot link a memory to itself") if from_memory_id.present? && from_memory_id == to_memory_id
  end

  def same_account
    return if from_memory_id.blank? || to_memory_id.blank?
    return if from_memory&.workspace&.account_id == to_memory&.workspace&.account_id
    errors.add(:base, "memories must belong to the same account")
  end
end
