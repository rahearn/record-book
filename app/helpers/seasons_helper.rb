module SeasonsHelper
  def season_summary(almanac, year, owner_count:, week_count:)
    if almanac.split_season?(year)
      premier = almanac.standings_for(year, :premier).size
      challenger = almanac.standings_for(year, :challenger).size
      "#{premier} in Premier, #{challenger} in Challenger · " \
        "#{almanac.promotion_count} promoted, #{almanac.relegation_count} relegated"
    else
      "#{pluralize(owner_count, 'owner')}, one league · #{pluralize(week_count, 'week')}"
    end
  end

  # Sits under the standings table: how the rows are ordered, and what
  # the shaded promotion/relegation zones mean.
  def season_zone_note(almanac, year, tier)
    ordering = "Ordered by final finish — playoff finishers first, then regular-season order."
    zone = if almanac.split_season?(year)
      if tier.to_s == "premier"
        "Shaded: bottom #{almanac.relegation_count} relegate to Challenger for #{year + 1}."
      else
        "Shaded: top #{almanac.promotion_count} promote to Premier for #{year + 1}."
      end
    elsif almanac.tiered_since
      "Single-tier season — promotion and relegation began in #{almanac.tiered_since}."
    else
      "Single-tier season."
    end
    "#{ordering} #{zone}"
  end

  def season_zone_class(almanac, record)
    if almanac.relegation_zone?(record)
      "zone-down"
    elsif almanac.promotion_zone?(record)
      "zone-up"
    end
  end

  # A playoff game's performances, winner first.
  def playoff_sides(game)
    game.performances.sort_by { |performance| -performance.points }
  end

  def playoff_note(format)
    return unless format

    "Top #{format.team_count} · from week #{format.start_week}"
  end

  def matrix_cell_class(cell)
    if cell.highest
      "tag tag-accent"
    elsif cell.lowest
      "tag tag-outline"
    else
      "tag"
    end
  end
end
