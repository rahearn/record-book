# The gate in front of /admin. The console has no user model — one set of HTTP
# basic credentials, kept in `Rails.application.credentials.active_admin`,
# stands in for one. Active Admin calls `authenticate_admin!` before every admin
# action (`config.authentication_method`), and its controllers descend from
# ApplicationController, which is why this is mixed in there rather than into an
# admin-only base class.
module AdminAuthentication
  extend ActiveSupport::Concern

  REALM = "Record Book Admin".freeze

  private

  def authenticate_admin!
    authenticate_or_request_with_http_basic(REALM) do |username, password|
      expected = admin_credentials
      # `&`, not `&&`: both comparisons always run, so a right username and a
      # wrong one take the same time.
      secure_match?(username, expected[:username]) & secure_match?(password, expected[:password])
    end
  end

  # A missing or half-filled entry is a deployment mistake, not a failed login:
  # say so rather than rejecting every correct password in silence.
  def admin_credentials
    credentials = Rails.application.credentials.active_admin
    return credentials if credentials&.values_at(:username, :password)&.all?(&:present?)

    raise "Admin credentials are missing. Add active_admin.username and " \
          "active_admin.password with `bin/rails credentials:edit`."
  end

  def secure_match?(given, expected)
    ActiveSupport::SecurityUtils.secure_compare(given.to_s, expected.to_s)
  end
end
