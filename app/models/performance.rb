class Performance < ApplicationRecord
  belongs_to :game
  belongs_to :owner
  has_many :lineup_slots, -> { ordered }, dependent: :destroy, inverse_of: :performance
  has_many :players, through: :lineup_slots

  validates :points, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :owner_id, uniqueness: { scope: :game_id }

  def lineup?
    lineup_slots.any?
  end

  def starters
    lineup_slots.select(&:starter?)
  end

  # Bench players, best score first — the ones that hurt to leave out.
  def bench
    lineup_slots.select(&:bench?).sort_by { |entry| -entry.points }
  end

  # The most the roster could have scored with hindsight: every starting
  # slot filled with the best eligible player still available, filling the
  # most restrictive slots first.
  def optimal_points
    pool = lineup_slots.map { |entry| [ entry.player.position, entry.points ] }
    starters.sort_by { |entry| entry.eligible_positions.size }.sum do |entry|
      best = pool.select { |position, _| entry.eligible_positions.include?(position) }.max_by(&:last)
      next 0 unless best

      pool.delete_at(pool.index(best))
      best.last
    end
  end

  # Points sacrificed to a suboptimal lineup. Zero when nothing on the
  # bench would have helped, or when no lineup is on record.
  def points_left_on_bench
    return 0 unless lineup?

    [ optimal_points - points, 0 ].max
  end
end
