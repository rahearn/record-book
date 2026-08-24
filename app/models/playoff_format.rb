class PlayoffFormat < ApplicationRecord
  include Tiered

  belongs_to :season

  validates :team_count, presence: true, numericality: { only_integer: true, greater_than: 1 }
  validates :start_week, presence: true, numericality: { only_integer: true, greater_than: 1 }
  validates :tier, uniqueness: { scope: :season_id }
end
