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
  # No joins(:pins) in the scope: the through association already joins pins on
  # THIS user, and a second join brought in every other user's pin on the same
  # record — so a teammate pinning what you pinned duplicated the row on your
  # own board. Ordering reads the through join.
  has_many :pinned_workspaces,
    -> { merge(Workspace.active).order("pins.created_at DESC") },
    through: :pins,
    source: :pinnable,
    source_type: "Workspace"
  has_many :pinned_memories,
    -> { order("pins.created_at DESC") },
    through: :pins,
    source: :pinnable,
    source_type: "Memory"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  scope :active, -> { where.not("email_address LIKE 'deleted-%'") }

  validates :role, presence: true, inclusion: {in: ROLES}
  # The only 8-character floor was minlength: 8 on the form fields, which any
  # non-browser client ignores — on the page whose whole job is credential
  # hygiene. allow_nil so records that are not setting a password still save.
  validates :password, length: {minimum: 8}, allow_nil: true
  validates :name, length: {maximum: 80}, allow_blank: true

  after_create :pin_account_defaults

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
  # The budget counts only what the person pinned themselves. Pins recuerd0
  # placed for them (starter maps, account defaults) are free.
  def pinned_items_count
    pins.user_origin.count
  end

  def system_pinned_items_count
    pins.system_origin.count
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

  private

  def pin_account_defaults
    Memory.joins(:workspace)
      .where(default_pinned: true)
      .where(workspaces: {
        account_id: account_id,
        archived_at: nil,
        deleted_at: nil
      })
      .order(:id)
      .each { |memory| memory.pin!(self, origin: "system") }
  end
end
