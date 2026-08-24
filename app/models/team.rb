class Team < ApplicationRecord
  belongs_to :owner
  belongs_to :season

  validates :name, presence: true
  validates :owner_id, uniqueness: { scope: :season_id }
end
