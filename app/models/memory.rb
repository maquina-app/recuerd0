class Memory < ApplicationRecord
  include Pinnable

  belongs_to :workspace, touch: true, counter_cache: true
  has_one :content, dependent: :destroy

  # Serialize tags as an array - Rails 7+ syntax
  serialize :tags, coder: JSON, type: Array

  # Create associated content after creating memory
  after_create :create_default_content

  private

  def create_default_content
    create_content(body: "")
  end
end
