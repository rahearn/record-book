require "test_helper"

class PlayoffFormatTest < ActiveSupport::TestCase
  test "fixture formats are valid" do
    assert playoff_formats(:premier_2024).valid?
  end

  test "team count and start week must be sensible" do
    format = PlayoffFormat.new(season: seasons(:y2023), team_count: 1, start_week: 1)
    assert_not format.valid?
    assert_includes format.errors[:team_count], "must be greater than 1"
    assert_includes format.errors[:start_week], "must be greater than 1"
  end

  test "one format per season and tier" do
    duplicate = PlayoffFormat.new(season: seasons(:y2024), tier: :premier,
                                  team_count: 4, start_week: 5)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:tier], "has already been taken"
  end

  test "season looks up the format for a tier" do
    assert_equal playoff_formats(:premier_2024), seasons(:y2024).playoff_format_for(:premier)
    assert_equal playoff_formats(:challenger_2024), seasons(:y2024).playoff_format_for("challenger")
    assert_nil seasons(:y2023).playoff_format_for(:unified)
  end
end
