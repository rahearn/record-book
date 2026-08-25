# One player's spot in an owner's lineup for a single game: which slot they
# filled and what they scored there. Bench players carry the points they
# would have scored, which is what makes "left on the bench" measurable.
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
  belongs_to :player

  # Injured reserve only existed in some seasons; it is a reserve slot like
  # the bench, except its occupant could not have been started.
  enum :slot, { qb: 0, rb: 1, wr: 2, te: 3, wr_rb_te: 4, k: 5, dst: 6,
                bench: 7, ir: 8, wr_rb: 9 }, default: :bench

  validates :points, presence: true, numericality: true
  validates :sequence, presence: true,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :performance_id }
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

  # How the record reads in the admin console's links, titles, and selects.
  def display_name
    "#{slot.upcase.tr('_', '/')} · #{player.display_name}"
  end

  # A player only needs one of their positions to match.
  def accepts?(candidate)
    eligible_positions.intersect?(candidate.positions)
  end

  private

  def player_eligible_for_slot
    return unless player && slot

    return if accepts?(player)

    errors.add(:player, "cannot fill a #{slot.upcase.tr('_', '/')} slot")
  end
end
