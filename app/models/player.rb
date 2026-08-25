# An NFL player (or team defense) who can be slotted into a weekly lineup.
# Players are shared across the league — the roster a player belonged to in
# a given week is recorded by the lineup slots that reference them. The NFL
# team both tells two same-named players apart and rides along in displays.
class Player < ApplicationRecord
  POSITIONS = %w[qb rb wr te k dst].freeze

  has_many :lineup_slots, dependent: :destroy

  # Rarely a player is eligible at more than one position. The order given
  # is kept — the first is the one they mostly play — so they read the way
  # a fantasy site lists them: "RB/WR".
  normalizes :positions, with: ->(values) { values.map { |value| value.to_s.strip.downcase }.uniq }
  normalizes :nfl_team, with: ->(team) { team.strip.upcase }

  validates :name, presence: true, uniqueness: { scope: :nfl_team }
  validates :nfl_team, presence: true
  validates :positions, presence: true
  validate :positions_are_known

  def eligible_for?(position)
    positions.include?(position.to_s)
  end

  # How the record reads in the admin console's links, titles, and selects.
  # The NFL team is what tells two same-named players apart.
  def display_name
    "#{name} (#{nfl_team})"
  end

  private

  def positions_are_known
    unknown = positions - POSITIONS
    errors.add(:positions, "#{unknown.to_sentence} is not a position") if unknown.any?
  end
end
