class AccountExport < ApplicationRecord
  MONTHLY_LIMIT = 2
  EXPIRY_DAYS = 5
  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :account
  belongs_to :user

  has_one_attached :archive

  validates :status, presence: true, inclusion: {in: STATUSES}

  scope :exports_this_month, -> {
    where(created_at: Time.current.beginning_of_month..Time.current.end_of_month)
  }
  scope :expired, -> { where("expires_at < ?", Time.current) }
  scope :completed, -> { where(status: "completed") }
  scope :in_progress, -> { where(status: %w[pending processing]) }

  def pending?
    status == "pending"
  end

  def processing?
    status == "processing"
  end

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def downloadable?
    completed? && !expired? && archive.attached?
  end

  def mark_processing!
    update!(status: "processing")
  end

  def mark_completed!
    update!(
      status: "completed",
      completed_at: Time.current,
      expires_at: EXPIRY_DAYS.days.from_now
    )
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message.to_s.truncate(500))
  end
end
