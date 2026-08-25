class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Ransack refuses to search or sort anything a model has not named, which
  # would leave every Active Admin filter raising. The record book holds no
  # secrets — league scores and the shape of the seasons they were played in —
  # and the console behind them is gated by HTTP basic auth, so every column and
  # association is fair game.
  def self.ransackable_attributes(_auth_object = nil)
    authorizable_ransackable_attributes
  end

  def self.ransackable_associations(_auth_object = nil)
    authorizable_ransackable_associations
  end
end
