# One player's spot in an owner's lineup for a single game: who filled it,
# what they scored there, and what the league considered them eligible for
# that week. Bench players carry the points they would have scored, which is
# what makes "left on the bench" measurable.
#
# The player is recorded on the slot rather than in a table of their own: an
# NFL team and a set of eligible positions are only true of one roster in one
# week, and both move within a season as readily as between them.
class LineupSlot < ApplicationRecord
  ANY_POSITION = %w[qb rb wr te k dst].freeze
  RESERVE_SLOTS = %w[bench ir].freeze

  # Which player positions each slot accepts. The league has run two flex
  # spots over the years: W/R took a back or receiver, and W/R/T, which
  # replaced it in 2009, opened up to tight ends. Reserves take anyone.
  ELIGIBLE_POSITIONS = {
    "qb" => %w[qb], "rb" => %w[rb], "wr" => %w[wr], "te" => %w[te],
    "wr_rb" => %w[rb wr], "wr_rb_te" => %w[rb wr te],
    "k" => %w[k], "dst" => %w[dst],
    "bench" => ANY_POSITION, "ir" => ANY_POSITION
  }.freeze

  belongs_to :performance

  # Injured reserve only existed in some seasons; it is a reserve slot like
  # the bench, except its occupant could not have been started.
  enum :slot, { qb: 0, rb: 1, wr: 2, te: 3, wr_rb_te: 4, k: 5, dst: 6,
                bench: 7, ir: 8, wr_rb: 9 }, default: :bench

  # Rarely a player is eligible at more than one position. The order given
  # is kept — the first is the one they mostly play — so they read the way
  # a fantasy site lists them: "RB/WR".
  normalizes :player_positions, with: ->(values) { values.map { |value| value.to_s.strip.downcase }.uniq }
  normalizes :player_nfl_team, with: ->(team) { team.strip.upcase }

  validates :player_name, presence: true
  validates :player_nfl_team, presence: true
  validates :player_positions, presence: true
  validates :points, presence: true, numericality: true
  validates :sequence, presence: true,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :performance_id }
  validate :player_positions_are_known
  validate :player_eligible_for_slot

  scope :ordered, -> { order(:sequence) }

  # Reserve slots do not score.
  def reserve?
    RESERVE_SLOTS.include?(slot)
  end

  def starter?
    !reserve?
  end

  # An injured player could not have been started, so hindsight cannot
  # seat them either.
  def startable?
    !ir?
  end

  def eligible_positions
    ELIGIBLE_POSITIONS.fetch(slot)
  end

  # Whether this slot could have taken the player who filled another one.
  # A player only needs one of their positions to match.
  def accepts?(entry)
    eligible_positions.intersect?(entry.player_positions)
  end

  def eligible_for?(position)
    player_positions.include?(position.to_s)
  end

  def slot_label
    slot.upcase.tr("_", "/")
  end

  # The player as they read in a lineup. The NFL team is what tells two
  # same-named players apart.
  def player_display_name
    "#{player_name} (#{player_nfl_team})"
  end

  # How the record reads in the admin console's links, titles, and selects.
  def display_name
    "#{slot_label} · #{player_display_name}"
  end

  private

  def player_positions_are_known
    unknown = player_positions - ANY_POSITION
    errors.add(:player_positions, "#{unknown.to_sentence} is not a position") if unknown.any?
  end

  def player_eligible_for_slot
    return if slot.blank? || player_positions.blank?

    return if accepts?(self)

    errors.add(:player_positions, "cannot fill a #{slot_label} slot")
  end
end
