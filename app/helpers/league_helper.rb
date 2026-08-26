module LeagueHelper
  TIER_LABELS = { "premier" => "Premier", "challenger" => "Challenger", "unified" => "Open" }.freeze
  TIER_TAG_CLASSES = {
    "premier" => "tag-accent", "challenger" => "tag-neutral", "unified" => "tag-outline"
  }.freeze
  MOVEMENT_LABELS = { promoted: "UP", relegated: "DOWN", held: "HELD" }.freeze
  MOVEMENT_TAG_CLASSES = { promoted: "tag-accent", relegated: "tag-neutral", held: "tag-outline" }.freeze

  # Scores are kept to a hundredth, the way the league has always scored
  # them, so a lineup's starters read as adding up to the score beside them.
  def points_display(value)
    format("%.2f", value)
  end

  def signed_points_display(value)
    format("%+.2f", value)
  end

  def win_percentage_display(value)
    format("%.1f%%", value * 100)
  end

  # "10–4", or "10–4–1" when the owner has ties on record.
  def record_display(record)
    parts = [ record.wins, record.losses ]
    parts << record.ties if record.ties.positive?
    parts.join("–")
  end

  def titles_display(count)
    count.zero? ? "—" : count.to_s
  end

  def tier_label(tier)
    TIER_LABELS.fetch(tier.to_s)
  end

  def tier_tag_class(tier)
    TIER_TAG_CLASSES.fetch(tier.to_s)
  end

  def movement_label(movement)
    MOVEMENT_LABELS.fetch(movement)
  end

  def movement_tag_class(movement)
    MOVEMENT_TAG_CLASSES.fetch(movement)
  end

  # A column header that sorts the all-time table: first click descending,
  # clicking the active column again flips the direction.
  def sortable_header(label, column, active_sort:, direction:, scope: nil)
    active = active_sort == column
    next_direction = active && direction == "desc" ? "asc" : "desc"
    caption = active ? "#{label} #{direction == 'asc' ? '▲' : '▼'}" : label
    link_to caption, root_path(sort: column, direction: next_direction, scope: scope), class: "hover:text-ink"
  end

  # When a single-game record was set: "2024 · Week 7".
  def record_date(record)
    "#{record.year} · Week #{record.week}"
  end

  def league_tagline(record_book)
    return "Record book" if record_book.empty?

    years = [ record_book.first_year, record_book.latest_year ].uniq.join("—")
    "Record book · #{years}"
  end

  def founders_note(count)
    "#{pluralize(count, 'founder')} #{count == 1 ? 'remains' : 'remain'}"
  end
end
