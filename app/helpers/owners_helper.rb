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

  def luck_note(luck_per_game)
    luck_per_game >= 0 ? "Opponents underperform vs. me" : "Opponents get up for me"
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
