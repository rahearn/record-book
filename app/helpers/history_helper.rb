module HistoryHelper
  VIEW_LABELS = { "seasons" => "Seasons", "games" => "Games", "players" => "Players" }.freeze
  PLAYER_SCOPE_LABELS = { "career" => "Careers", "season" => "Seasons", "game" => "Single games" }.freeze

  # What the games table is showing, by the column it is sorted on: the
  # top of a column descending, the bottom of it ascending.
  GAME_HEADINGS = {
    "points" => [ "Highest scores", "Lowest scores" ],
    "opp_points" => [ "Most points allowed", "Fewest points allowed" ],
    "margin" => [ "Biggest wins", "Worst losses" ],
    "combined" => [ "Highest-scoring games", "Lowest-scoring games" ],
    "all_play" => [ "Best weeks against the field", "Worst weeks against the field" ],
    "vs_avg" => [ "Furthest above their average", "Furthest below their average" ]
  }.freeze

  PLAYER_HEADINGS = {
    "career" => "Player careers", "season" => "Player seasons", "game" => "Single-game starts"
  }.freeze

  PLAYER_COUNT_NOUNS = { "career" => "player", "season" => "player season", "game" => "start" }.freeze

  def history_view_label(view)
    VIEW_LABELS.fetch(view)
  end

  # The filters and the player grouping carry from tab to tab; the sort
  # belongs to the table it was chosen on and does not.
  def history_tab_path(view: @view, **overrides)
    history_path(view: view, owner: @owner&.id,
                 **(view == "players" ? { position: @position, by: @player_scope } : {}), **overrides)
  end

  # A history header that re-sorts the table it heads, filters kept.
  def history_sort_header(label, column)
    sortable_header(label, column, active_sort: @sort, direction: @direction, path: :history_tab_path)
  end

  def history_summary(almanac, view)
    years = "#{almanac.first_year}–#{almanac.latest_year}"
    case view
    when "seasons" then "Every owner's regular season, #{years}"
    when "games" then "Every regular-season score, #{years}"
    when "players" then "Every player started, from the lineups on record"
    end
  end

  def game_history_heading(sort, direction)
    descending, ascending = GAME_HEADINGS.fetch(sort)
    direction == "asc" ? ascending : descending
  end

  # "Top 50 of 3,412 scores", or the whole count when every row is shown.
  def history_count_note(shown, total, noun)
    counted = pluralize(number_with_delimiter(total), noun)
    shown < total ? "Top #{shown} of #{counted}" : counted.capitalize
  end

  def player_scope_labels
    PLAYER_SCOPE_LABELS
  end

  def player_history_heading(scope)
    PLAYER_HEADINGS.fetch(scope)
  end

  def player_count_note(shown, total, scope)
    history_count_note(shown, total, PLAYER_COUNT_NOUNS.fetch(scope))
  end

  # The span of seasons a player appears in: "2014–2019", or one year.
  def player_years_display(line)
    [ line.first_year, line.last_year ].uniq.join("–")
  end

  def points_per_start_display(line)
    per_start = line.points_per_start
    per_start ? points_display(per_start) : "—"
  end

  def best_start_display(line)
    line.best ? points_display(line.best) : "—"
  end

  def position_options
    LineupSlot::ANY_POSITION.map { |position| [ position_label(position), position ] }
  end

  def season_history_note(almanac)
    note = "Regular-season games only. Finish is where the season ended — playoff finishers first."
    unless almanac.season_complete?(almanac.latest_year)
      note += " #{almanac.latest_year} is still being played; its totals are to date."
    end
    "#{note} #{luck_column_note}"
  end

  def game_history_note(sort)
    note = "Regular-season games only. Margin is from the owner's side; all-play is the week's " \
      "score against every other score that week; vs avg is against the owner's own season average."
    sort == "combined" ? "#{note} Each game is listed once, under its higher score." : note
  end

  def player_history_note(ledger, scope, sort)
    since = ledger.first_year
    note = "Regular-season starts only, from the lineups on record#{" (since #{since})" if since}. " \
      "A player is a name at a position, listed with their latest NFL team."
    note += " Bench is points scored while on the bench." unless scope == "game"
    if sort == "ppg" && scope != "game"
      note += " Pts/start needs #{pluralize(PlayerLedger::QUALIFYING_STARTS.fetch(scope.to_sym), 'start')} to qualify."
    end
    note
  end
end
