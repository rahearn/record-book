# An NFL player (or team defense) who can be slotted into a weekly lineup.
# Players are shared across the league — the roster a player belonged to in
# a given week is recorded by the lineup slots that reference them. The NFL
# team both tells two same-named players apart and rides along in displays.
class Player < ApplicationRecord
  has_many :lineup_slots, dependent: :destroy

  enum :position, { qb: 0, rb: 1, wr: 2, te: 3, k: 4, dst: 5 }, default: :qb

  normalizes :nfl_team, with: ->(team) { team.strip.upcase }

  validates :name, presence: true, uniqueness: { scope: [ :position, :nfl_team ] }
  validates :nfl_team, presence: true
end
