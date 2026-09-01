module MatchupsHelper
  POSITION_LABELS = {
    "qb" => "QB", "rb" => "RB", "wr" => "WR", "te" => "TE", "k" => "K", "dst" => "D/ST"
  }.freeze
  SLOT_LABELS = POSITION_LABELS.merge(
    "wr_rb" => "W/R", "wr_rb_te" => "W/R/T", "bench" => "BN", "ir" => "IR"
  ).freeze

  def position_label(position)
    POSITION_LABELS.fetch(position.to_s)
  end

  # Every position the player in this slot was eligible at that week,
  # primary first: "RB" or "RB/WR".
  def player_positions_label(entry)
    entry.player_positions.map { |position| position_label(position) }.join("/")
  end

  def slot_label(slot)
    SLOT_LABELS.fetch(slot.to_s)
  end

  # A player as they read in a lineup: their name, then the NFL team they
  # played for that week — which is also what tells two same-named players
  # apart.
  def player_with_team(entry)
    safe_join([ entry.player_name, tag.span(entry.player_nfl_team, class: "text-ink/55") ], " ")
  end

  # "Week 3 · 2024", with the round name added for playoff games.
  def matchup_title(matchup)
    title = "Week #{matchup.week} · #{matchup.year}"
    matchup.playoff? ? "#{title} · #{matchup.round_name}" : title
  end

  def matchup_result_note(matchup)
    if matchup.tied?
      "Tied at #{points_display(matchup.side_a.points)}."
    else
      "#{matchup.winner.name} wins by #{points_display(matchup.margin)}."
    end
  end

  # A score set against the owner's own season average, or a dash when that
  # season has no regular-season games on record.
  def vs_season_average_display(side)
    side.points_vs_average ? signed_points_display(side.points_vs_average) : "—"
  end

  def season_context_note(side)
    return "No season on record" unless side.season_record

    "#{record_display(side.season_record)} that year · season avg " \
      "#{points_display(side.average_points)} (#{vs_season_average_display(side)} this week)"
  end

  # A side's record against every other score in the same week, or nothing
  # for a playoff game, which is not part of the regular-season field.
  def matchup_all_play_note(side)
    return unless side.all_play

    "All-play #{all_play_display(side.all_play)} that week"
  end

  def bench_note(side)
    "#{points_display(side.points_left_on_bench)} left on the bench"
  end

  # Bars are scaled against the best starting score in the game.
  def lineup_bar_percent(points, best)
    bar_percent(points, best.positive? ? best : 1)
  end

  def lineup_bar_class(leading)
    leading ? "bg-accent" : "bg-neutral-400"
  end
end
