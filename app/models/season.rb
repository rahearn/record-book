class Season < ApplicationRecord
  has_many :games, dependent: :destroy

  validates :year, presence: true, uniqueness: true,
    numericality: { only_integer: true, greater_than: 1900 }

  scope :chronological, -> { order(:year) }
end
