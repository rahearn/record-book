module ApplicationHelper
  # Registration marks drawn at the four corners of a .blueprint box.
  def blueprint_corners
    safe_join(%w[tl tr bl br].map { |position| tag.i(class: "corner #{position}") })
  end

  # The current season is the front page; earlier seasons keep their own
  # path. Takes the year positionally or, for sortable_header, as a keyword.
  def season_page_path(positional_year = nil, year: positional_year, **params)
    year.to_i == @almanac&.latest_year ? root_path(**params) : season_path(year, **params)
  end

  def nav_button(label, path, active:)
    link_to label, path, class: "btn #{active ? 'btn-primary' : 'btn-secondary'}"
  end
end
