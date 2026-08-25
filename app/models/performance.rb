class Performance < ApplicationRecord
  belongs_to :game
  belongs_to :owner
  has_many :lineup_slots, -> { ordered }, dependent: :destroy, inverse_of: :performance
  has_many :players, through: :lineup_slots

  validates :points, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :owner_id, uniqueness: { scope: :game_id }

  # The optimal lineup is memoized, so a reload has to drop it along with
  # the association cache it was computed from.
  def reload(...)
    @optimal_points = nil
    super
  end

  def lineup?
    lineup_slots.any?
  end

  def starters
    lineup_slots.select(&:starter?)
  end

  # Everyone who did not score: the bench best score first — the ones that
  # hurt to leave out — and then anyone on injured reserve.
  def reserves
    lineup_slots.select(&:reserve?).sort_by { |entry| [ entry.ir? ? 1 : 0, -entry.points ] }
  end

  # The most the roster could have scored with hindsight. Filling the most
  # restrictive slot first is not enough — a player eligible at two
  # positions can be worth more in the slot they are not the best fit for —
  # so this searches every legal lineup: the best total for each set of
  # slots already filled, one player at a time. That is 2^slots states,
  # which stays small at fantasy lineup sizes.
  def optimal_points
    @optimal_points ||= begin
      slots = starters
      complete = (1 << slots.size) - 1
      best = Array.new(complete + 1)
      best[0] = 0
      lineup_slots.select(&:startable?).each do |entry|
        openings = slots.each_index.select { |index| slots[index].accepts?(entry.player) }
        best = seat(entry, openings, best)
      end
      best[complete] || slots.sum(&:points)
    end
  end

  # Points sacrificed to a suboptimal lineup. Zero when nothing on the
  # bench would have helped, or when no lineup is on record.
  def points_left_on_bench
    return 0 unless lineup?

    [ optimal_points - points, 0 ].max
  end

  private

  # Every way this player could improve on the lineups found so far, plus
  # the option of leaving them out. `openings` are the slots they are
  # eligible for, worked out once rather than at every state.
  def seat(entry, openings, best)
    carried = best.dup
    best.each_with_index do |total, mask|
      next unless total

      candidate = total + entry.points
      openings.each do |index|
        bit = 1 << index
        next if mask.anybits?(bit)

        filled = mask | bit
        carried[filled] = candidate if carried[filled].nil? || candidate > carried[filled]
      end
    end
    carried
  end
end
