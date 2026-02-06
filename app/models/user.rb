class User < ApplicationRecord
  PIN_LIMIT = 10
  ROLES = %w[admin member].freeze

  has_secure_password
  belongs_to :account
  has_many :sessions, dependent: :destroy
  has_many :access_tokens, dependent: :destroy
  has_many :account_exports, dependent: :destroy

  # Pin associations
  has_many :pins, dependent: :destroy
  has_many :pinned_workspaces,
    -> { joins(:pins).merge(Workspace.active).order("pins.created_at DESC") },
    through: :pins,
    source: :pinnable,
    source_type: "Workspace"
  has_many :pinned_memories,
    -> { joins(:pins).order("pins.created_at DESC") },
    through: :pins,
    source: :pinnable,
    source_type: "Memory"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  scope :active, -> { where.not("email_address LIKE 'deleted-%'") }

  validates :role, presence: true, inclusion: {in: ROLES}
  validates :name, length: {maximum: 80}, allow_blank: true

  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end

  def anonymize_email!
    domain = email_address.split("@").last
    update!(email_address: "deleted-#{SecureRandom.hex(8)}@#{domain}")
  end

  def anonymized?
    email_address.start_with?("deleted-")
  end

  # Helper methods
  def pinned_items_count
    pins.count
  end

  def can_pin_more?
    pinned_items_count < PIN_LIMIT
  end

  def reorder_pins!(pinnable_type, new_order)
    pins.where(pinnable_type: pinnable_type).each do |pin|
      new_position = new_order.index(pin.pinnable_id)
      pin.update!(position: new_position) if new_position
    end
  end
end
