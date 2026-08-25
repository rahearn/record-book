# The admin console: CRUD over the record book's own tables, mounted at /admin
# and gated by HTTP basic auth. Every setting Active Admin offers is documented
# at https://activeadmin.info/documentation.html — only the ones this app moves
# off their defaults are set here.
ActiveAdmin.setup do |config|
  config.site_title = "Record Book"

  # There is no admin user model. `authenticate_admin!` (see
  # AdminAuthentication) checks the single set of HTTP basic credentials held in
  # Rails.application.credentials.active_admin, so there is nobody to be the
  # "current user" and nothing to log out of.
  config.authentication_method = :authenticate_admin!
  config.current_user_method = false
  config.logout_link_path = nil

  # Comments are authored by an admin user, which this console does not have.
  config.comments = false

  config.batch_actions = true

  # Beyond this many rows an association filter drops its select for a text
  # match — the lineup slots and performances tables are far past it.
  config.maximum_association_filter_arity = 256
  config.localize_format = :long
  config.filter_attributes = [ :encrypted_password, :password, :password_confirmation ]
end
