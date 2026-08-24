# One player's spot in an owner's lineup for a single game: which slot they
# filled and what they scored there. Bench players carry the points they
# would have scored, which is what makes "left on the bench" measurable.
class LineupSlot < ApplicationRecord
  # Which player positions each slot accepts. FLEX takes a running back,
  # receiver, or tight end; the bench takes anyone.
  ELIGIBLE_POSITIONS = {
    "qb" => %w[qb], "rb" => %w[rb], "wr" => %w[wr], "te" => %w[te],
    "flex" => %w[rb wr te], "k" => %w[k], "dst" => %w[dst],
    "bench" => %w[qb rb wr te k dst]
  }.freeze

  belongs_to :performance
  belongs_to :player

  enum :slot, { qb: 0, rb: 1, wr: 2, te: 3, flex: 4, k: 5, dst: 6, bench: 7 }, default: :bench

  validates :points, presence: true, numericality: true
  validates :sequence, presence: true,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :performance_id }
  validate :player_eligible_for_slot

  scope :ordered, -> { order(:sequence) }

  def starter?
    !bench?
  end

  def eligible_positions
    ELIGIBLE_POSITIONS.fetch(slot)
  end

  private

  def player_eligible_for_slot
    return unless player && slot

    unless eligible_positions.include?(player.position)
      errors.add(:player, "cannot fill the #{slot} slot")
    end
  end
end
