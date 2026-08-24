class Game < ApplicationRecord
  include Tiered

  # Round names with rule significance: the Championship decides the title
  # and, with the Third Place game, the playoff finishing order; the
  # Semifinal feeds the owners' playoff-history stats.
  CHAMPIONSHIP = "Championship".freeze
  THIRD_PLACE = "Third Place".freeze
  SEMIFINAL = "Semifinal".freeze

  belongs_to :season
  has_many :performances, dependent: :destroy
  has_many :owners, through: :performances

  validates :week, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :round_name_consistent_with_playoff_format

  scope :playoff, -> { where.not(round_name: nil) }
  scope :regular_season, -> { where(round_name: nil) }

  def playoff?
    round_name.present?
  end

  def regular_season?
    !playoff?
  end

  def championship?
    round_name == CHAMPIONSHIP
  end

  def third_place?
    round_name == THIRD_PLACE
  end

  private

  # When the season/tier has a configured playoff format, games from the
  # start week on are playoff games and earlier games are not.
  def round_name_consistent_with_playoff_format
    return unless season
    format = season.playoff_format_for(tier)
    return unless format

    if playoff? && week && week < format.start_week
      errors.add(:round_name, "cannot be set before playoff week #{format.start_week}")
    elsif regular_season? && week && week >= format.start_week
      errors.add(:round_name, "must be set for playoff week #{format.start_week} and later")
    end
  end
end
