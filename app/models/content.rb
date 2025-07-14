class Content < ApplicationRecord
  belongs_to :memory, touch: true

  validates :body, presence: false # Allow empty body initially
end
