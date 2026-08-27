module HeadToHeadHelper
  ComparisonRow = Data.define(:label, :a_display, :b_display, :a_bar, :b_bar)

  def series_display(series)
    parts = [ series.wins_a, series.wins_b ]
    parts << series.ties if series.ties.positive?
    parts.join("–")
  end

  def series_note(series)
    return "These owners have never met." if series.games_played.zero?

    note = "#{pluralize(series.games_played, 'meeting')} since #{series.first_year}"
    return note unless series.playoff_meetings.positive?

    "#{note} · #{series.playoff_meetings} in the playoffs"
  end

  def h2h_comparison_rows(series, career_a, career_b)
    [
      comparison_row("Avg in series", series.average_points_a, series.average_points_b) { |value| points_display(value) },
      comparison_row("Career PF/g", career_a.points_for_per_game, career_b.points_for_per_game) { |value| points_display(value) },
      comparison_row("Career PA/g", career_a.points_against_per_game, career_b.points_against_per_game) { |value| points_display(value) },
      comparison_row("Career win%", career_a.win_percentage * 100, career_b.win_percentage * 100) { |value| format("%.1f%%", value) },
      comparison_row("Luck", career_a.luck_per_game, career_b.luck_per_game) { |value| signed_points_display(value) }
    ]
  end

  private

  # Bars scale against the larger of the two magnitudes so the leader's
  # bar is always full.
  def comparison_row(label, value_a, value_b)
    max = [ value_a.abs, value_b.abs ].max
    max = 1 if max.zero?
    ComparisonRow.new(label: label, a_display: yield(value_a), b_display: yield(value_b),
                      a_bar: format("%d%%", value_a.abs / max * 100),
                      b_bar: format("%d%%", value_b.abs / max * 100))
  end
end
