class MemoryLink < ApplicationRecord
  belongs_to :from_memory, class_name: "Memory"
  belongs_to :to_memory, class_name: "Memory"

  before_validation :normalize_order
  validate :different_memories
  validate :same_account
  validates :from_memory_id, uniqueness: {scope: :to_memory_id}

  scope :involving, ->(memory) {
    where(from_memory_id: memory.id).or(where(to_memory_id: memory.id))
  }

  def other_side(memory)
    (from_memory_id == memory.id) ? to_memory : from_memory
  end

  private

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
