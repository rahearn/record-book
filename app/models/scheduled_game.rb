# A regular-season matchup on the schedule that has not been played yet.
# It carries no scores, so it is kept apart from Game, whose two
# performances always have them; once the week is played the importer
# writes the game and clears this out. The remaining schedule is what a
# season's strength of schedule is measured over.
class ScheduledGame < ApplicationRecord
  include Tiered

  belongs_to :season
  belongs_to :owner_a, class_name: "Owner"
  belongs_to :owner_b, class_name: "Owner"

  validates :week, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validate :owners_differ

  def owners
    [ owner_a, owner_b ]
  end

  # The other side of the matchup from the given owner, or nil when they
  # are not playing in it.
  def opponent_of(owner)
    if owner_a == owner
      owner_b
    elsif owner_b == owner
      owner_a
    end
  end

  # How the record reads in the admin console's links, titles, and selects.
  def display_name
    [ "#{season.year} Week #{week}", (tier.titleize unless unified?),
      "#{owner_a.name} vs #{owner_b.name}" ].compact.join(" · ")
  end

  private

  def owners_differ
    errors.add(:owner_b, "cannot play themselves") if owner_a_id && owner_a_id == owner_b_id
  end
end
