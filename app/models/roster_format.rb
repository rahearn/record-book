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

  # Seat a week's starters into this season's starting slots. Sources record
  # that a player started, not the slot they filled, so the slot has to be
  # worked back out of what they were eligible for. Filling the most
  # restrictive slot first is not enough — a player eligible at two positions
  # can be the only one who fits somewhere else — so this searches for a
  # seating that takes everyone, giving up a slot it has already filled when
  # that slot's occupant can sit elsewhere.
  #
  # `positions` holds one player's eligible positions per entry. Returns the
  # index into `positions` that each starting slot takes, nil for a slot
  # nobody fills, or nil overall when some player cannot be seated at all.
  def seat_starters(positions)
    slots = starting_slots
    taken = Array.new(slots.size)
    seat = lambda do |player, tried|
      slots.each_with_index do |slot, index|
        next if tried.include?(index)
        next unless LineupSlot::ELIGIBLE_POSITIONS.fetch(slot).intersect?(positions[player])

        tried << index
        if taken[index].nil? || seat.call(taken[index], tried)
          taken[index] = player
          return true
        end
      end
      false
    end

    positions.each_index { |player| return nil unless seat.call(player, Set.new) }
    taken
  end

  def size
    slots.size
  end

  # How the record reads in the admin console's links, titles, and selects.
  def display_name
    "#{season.year} roster"
  end

  private

  def slots_are_known
    unknown = slots.uniq - LineupSlot.slots.keys
    errors.add(:slots, "#{unknown.to_sentence} is not a slot") if unknown.any?
  end
end
