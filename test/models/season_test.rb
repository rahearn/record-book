require "test_helper"

class SeasonTest < ActiveSupport::TestCase
  test "fixture seasons are valid" do
    assert seasons(:y2023).valid?
  end

  test "year must be unique" do
    season = Season.new(year: 2023)
    assert_not season.valid?
    assert_includes season.errors[:year], "has already been taken"
  end

  test "year must be a plausible integer" do
    assert_not Season.new(year: nil).valid?
    assert_not Season.new(year: 1850).valid?
  end

  test "chronological orders by year" do
    assert_equal [ seasons(:y2023), seasons(:y2024) ], Season.chronological.to_a
  end
end
