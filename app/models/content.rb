class Content < ApplicationRecord
  belongs_to :memory

  validates :body, presence: false # Allow empty body initially
end
