module WeeksHelper
  def week_title(year, week)
    "Week #{week} · #{year}"
  end

  def week_summary(scoreboard, split:)
    league = split ? tier_label(scoreboard.tier) : "League"
    "#{league} · high #{points_display(scoreboard.highest_score)} · " \
      "low #{points_display(scoreboard.lowest_score)} · " \
      "average #{points_display(scoreboard.average_score)}"
  end

  # The week's top score wears a filled tag, its low score an outlined one.
  def scoreboard_badge(scoreboard, side)
    if scoreboard.highest?(side)
      [ "HIGH", "tag-accent" ]
    elsif scoreboard.lowest?(side)
      [ "LOW", "tag-outline" ]
    end
  end

  def scoreboard_side_class(matchup, side)
    matchup.winner == side.owner ? "font-semibold" : nil
  end

  def week_button_class(week, current)
    "btn #{week == current ? 'btn-primary' : 'btn-secondary'} min-w-[38px] px-2 py-1"
  end
end
