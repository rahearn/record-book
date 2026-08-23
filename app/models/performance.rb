class Performance < ApplicationRecord
  belongs_to :game
  belongs_to :owner

  validates :points, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :owner_id, uniqueness: { scope: :game_id }
end
