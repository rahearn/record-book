class Owner < ApplicationRecord
  has_many :performances, dependent: :destroy
  has_many :games, through: :performances
  has_many :teams, dependent: :destroy

  validates :name, presence: true, uniqueness: true

  def initials
    name.split.map { |part| part[0] }.join.upcase
  end

  # Team names change season to season; outside a season context, the most
  # recent season's name represents the owner.
  def team_name
    teams.max_by { |team| team.season.year }&.name
  end

  def team_name_in(year)
    teams.detect { |team| team.season.year == year }&.name || team_name
  end
end
