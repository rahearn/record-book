class Owner < ApplicationRecord
  has_many :performances, dependent: :destroy
  has_many :games, through: :performances
  has_many :teams, dependent: :destroy
  has_many :scheduled_games_as_a, class_name: "ScheduledGame", foreign_key: :owner_a_id,
    dependent: :destroy, inverse_of: :owner_a
  has_many :scheduled_games_as_b, class_name: "ScheduledGame", foreign_key: :owner_b_id,
    dependent: :destroy, inverse_of: :owner_b

  validates :name, presence: true, uniqueness: true

  def initials
    name.split.map { |part| part[0] }.join.upcase
  end

  # Team names change season to season; outside a season context, the most
  # recent season's name represents the owner.
  def team_name
    teams.joins(:season).order(seasons: { year: :desc }).first&.name
  end

  def team_name_in(year)
    teams.joins(:season).where(season: { year: }).first&.name || team_name
  end

  # Whether this owner fielded a team in the given season.
  def current_in?(year)
    teams.joins(:season).where(season: { year: }).exists?
  end
end
