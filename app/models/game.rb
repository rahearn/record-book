class Game < ApplicationRecord
  belongs_to :season
  has_many :performances, dependent: :destroy
  has_many :owners, through: :performances

  enum :tier, { unified: 0, premier: 1, challenger: 2 }, default: :unified

  validates :week, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
