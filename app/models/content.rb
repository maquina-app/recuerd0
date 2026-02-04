class Content < ApplicationRecord
  belongs_to :memory, touch: true
end
