module ApplicationHelper
  # Registration marks drawn at the four corners of a .blueprint box.
  def blueprint_corners
    safe_join(%w[tl tr bl br].map { |position| tag.i(class: "corner #{position}") })
  end
end
