class ApplicationController < ActionController::Base
  # Active Admin's controllers inherit from this one and call `authenticate_admin!`.
  include AdminAuthentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
