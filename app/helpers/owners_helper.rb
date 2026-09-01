module OwnersHelper
  # Current owners (a team in the most recent season) first, then everyone
  # else, alphabetical by name within each group.
  def owner_select_options(almanac)
    current, former = almanac.all_time_standings
      .sort_by { |career| career.owner.name }
      .partition { |career| career.owner.current_in?(almanac.latest_year) }

    [ [ "Current", owner_option_pairs(current) ], [ "Former", owner_option_pairs(former) ] ]
      .reject { |_label, pairs| pairs.empty? }
  end

  def finish_display(rank)
    rank == 1 ? "1st ★" : rank.ordinalize
  end

  def owner_blurb(almanac, career)
    parts = [ pluralize(career.seasons_played, "season"), "joined #{career.joined_year}" ]
    if career.next_tier
      parts << "#{tier_label(career.next_tier)} in #{almanac.ladder.year}"
    end
    parts.join(" · ")
  end

  def league_rank_note(rank, total)
    "League rank #{rank} of #{total}"
  end

  # The luck plate reads as the record against the schedule that earned it.
  def luck_note(career)
    "#{record_display(career)} against a #{wins_display(career.expected_wins)}-win schedule"
  end

  # Under the week-by-week chart: the season's schedule, and the results
  # that turned on how the opponent scored against their own year.
  def week_luck_note(record)
    "#{record_display(record)} against a #{wins_display(record.expected_wins)}-win schedule · " \
      "#{pluralize(record.swing_wins_gained.round, 'win')} needed an opponent scoring below their own " \
      "season average, #{pluralize(record.swing_wins_lost.round, 'loss', plural: 'losses')} came against " \
      "one who beat theirs. Outlined weeks went against the all-play field."
  end

  def best_finish_note(career)
    "Best finish: #{career.best_finish.ordinalize}"
  end

  def year_or_dash(year)
    year&.to_s || "—"
  end

  def bar_percent(value, max)
    format("%.1f%%", value.to_f / max * 100)
  end

  def week_result_label(score)
    { win: "W", loss: "L", tie: "T" }.fetch(score.result)
  end

  def week_result_tag_class(score)
    { win: "tag-accent", loss: "tag-neutral", tie: "tag-outline" }.fetch(score.result)
  end

  private

  def owner_option_pairs(careers)
    careers.map { |career| [ "#{career.owner.name} — #{career.owner.team_name}", career.owner.id ] }
  end
end
