module LeagueHelper
  TIER_LABELS = { "premier" => "Premier", "challenger" => "Challenger", "unified" => "Open" }.freeze
  TIER_TAG_CLASSES = {
    "premier" => "tag-accent", "challenger" => "tag-neutral", "unified" => "tag-outline"
  }.freeze
  MOVEMENT_LABELS = { promoted: "UP", relegated: "DOWN", held: "HELD" }.freeze
  MOVEMENT_TAG_CLASSES = { promoted: "tag-accent", relegated: "tag-neutral", held: "tag-outline" }.freeze

  def points_display(value)
    format("%.1f", value)
  end

  def signed_points_display(value)
    format("%+.1f", value)
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

  def league_tagline(record_book)
    return "Record book" if record_book.empty?

    years = [ record_book.first_year, record_book.latest_year ].uniq.join("—")
    "Record book · #{years}"
  end

  def founders_note(count)
    "#{pluralize(count, 'founder')} #{count == 1 ? 'remains' : 'remain'}"
  end
end
