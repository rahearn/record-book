class Owner < ApplicationRecord
  has_many :performances, dependent: :destroy
  has_many :games, through: :performances

  validates :name, presence: true, uniqueness: true
  validates :team_name, presence: true

  def initials
    name.split.map { |part| part[0] }.join.upcase
  end
end
