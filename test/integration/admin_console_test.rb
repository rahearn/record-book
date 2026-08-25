require "test_helper"

class AdminConsoleTest < ActionDispatch::IntegrationTest
  RESOURCES = %w[owners seasons teams games performances players playoff_formats roster_formats
                 lineup_slots].freeze

  test "the console is closed without credentials" do
    get admin_root_path

    assert_response :unauthorized
    assert_match(/Basic realm/, response.headers["WWW-Authenticate"])
  end

  test "the console is closed to the wrong password" do
    get admin_root_path, headers: auth_header(password: "not-the-password")

    assert_response :unauthorized
  end

  test "the console is closed to the wrong username" do
    get admin_root_path, headers: auth_header(username: "nobody")

    assert_response :unauthorized
  end

  test "the dashboard opens with the right credentials" do
    get admin_root_path, headers: auth_header

    assert_response :success
    assert_includes response.body, "The record book"
  end

  test "every resource lists, shows, and offers a form" do
    RESOURCES.each do |resource|
      record = resource.classify.constantize.first

      get "/admin/#{resource}", headers: auth_header
      assert_response :success, "index of #{resource}"

      get "/admin/#{resource}/new", headers: auth_header
      assert_response :success, "new #{resource}"

      get "/admin/#{resource}/#{record.id}", headers: auth_header
      assert_response :success, "show of #{resource}"

      get "/admin/#{resource}/#{record.id}/edit", headers: auth_header
      assert_response :success, "edit of #{resource}"
    end
  end

  test "an owner can be created, renamed, and removed" do
    assert_difference -> { Owner.count }, 1 do
      post admin_owners_path, params: { owner: { name: "Newcomer" } }, headers: auth_header
    end
    owner = Owner.find_by(name: "Newcomer")

    patch admin_owner_path(owner), params: { owner: { name: "Renamed" } }, headers: auth_header
    assert_equal "Renamed", owner.reload.name

    assert_difference -> { Owner.count }, -1 do
      delete admin_owner_path(owner), headers: auth_header
    end
  end

  test "a player's positions are entered as one comma-separated field" do
    post admin_players_path,
      params: { player: { name: "Flex Guy", nfl_team: "sea", positions: "wr, rb" } },
      headers: auth_header

    player = Player.find_by(name: "Flex Guy")
    assert_equal %w[wr rb], player.positions
    assert_equal "SEA", player.nfl_team

    patch admin_player_path(player), params: { player: { positions: "rb" } }, headers: auth_header
    assert_equal %w[rb], player.reload.positions
  end

  test "a roster format's slots keep their order and repeats" do
    season = Season.create!(year: 1999)

    post admin_roster_formats_path,
      params: { roster_format: { season_id: season.id, slots: "qb, rb, rb, wr, wr, bench, bench" } },
      headers: auth_header

    assert_equal %w[qb rb rb wr wr bench bench], season.reload.roster_format.slots
  end

  test "a game carries its two performances" do
    season = seasons(:y2023)
    owners = Owner.order(:name).first(2)

    assert_difference -> { Game.count }, 1 do
      post admin_games_path, params: { game: {
        season_id: season.id, week: 1, tier: "unified", round_name: "",
        performances_attributes: {
          "0" => { owner_id: owners.first.id, points: 101.5 },
          "1" => { owner_id: owners.second.id, points: 99.5 }
        }
      } }, headers: auth_header
    end

    game = Game.order(:id).last
    assert_equal [ 99.5, 101.5 ], game.performances.map { |performance| performance.points.to_f }.sort
  end

  test "invalid input is reported rather than saved" do
    assert_no_difference -> { Owner.count } do
      post admin_owners_path, params: { owner: { name: "" } }, headers: auth_header
    end

    assert_response :unprocessable_entity
  end

  private

  def auth_header(username: nil, password: nil)
    credentials = Rails.application.credentials.active_admin
    encoded = ActionController::HttpAuthentication::Basic.encode_credentials(
      username || credentials[:username], password || credentials[:password])
    { "HTTP_AUTHORIZATION" => encoded }
  end
end
