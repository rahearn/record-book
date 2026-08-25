class Season < ApplicationRecord
  has_many :games, dependent: :destroy
  has_many :teams, dependent: :destroy
  has_many :playoff_formats, dependent: :destroy
  has_one :roster_format, dependent: :destroy

  validates :year, presence: true, uniqueness: true,
    numericality: { only_integer: true, greater_than: 1900 }

  scope :chronological, -> { order(:year) }

  # How the record reads in the admin console's links, titles, and selects.
  def display_name
    year.to_s
  end

  def playoff_format_for(tier)
    playoff_formats.detect { |format| format.tier == tier.to_s }
  end
end
