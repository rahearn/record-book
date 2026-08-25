# The lineup a season was played with: every slot an owner filled that
# year, starters first in the order they read and the reserve slots behind
# them. The league's shape has moved a lot — a flex spot arrived in 2006
# and widened in 2009, kickers were dropped after 2009, and the bench has
# been as deep as seven and as shallow as three.
class RosterFormat < ApplicationRecord
  belongs_to :season

  validates :season_id, uniqueness: true
  validates :slots, presence: true
  validate :slots_are_known

  def starting_slots
    slots - LineupSlot::RESERVE_SLOTS
  end

  def reserve_slots
    slots.select { |slot| LineupSlot::RESERVE_SLOTS.include?(slot) }
  end

  def bench_count
    slots.count("bench")
  end

  def injured_reserve?
    slots.include?("ir")
  end

  # How many of each slot a lineup must carry — the shape a recorded
  # lineup is held to, without insisting on the order it was written in.
  def slot_counts
    slots.tally
  end

  def size
    slots.size
  end

  private

  def slots_are_known
    unknown = slots.uniq - LineupSlot.slots.keys
    errors.add(:slots, "#{unknown.to_sentence} is not a slot") if unknown.any?
  end
end
