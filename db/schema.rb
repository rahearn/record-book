# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_25_231340) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "round_name"
    t.bigint "season_id", null: false
    t.integer "tier", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "week", null: false
    t.index ["season_id", "week"], name: "index_games_on_season_id_and_week"
    t.index ["season_id"], name: "index_games_on_season_id"
  end

  create_table "lineup_slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "performance_id", null: false
    t.string "player_name", null: false
    t.string "player_nfl_team", null: false
    t.string "player_positions", default: [], null: false, array: true
    t.decimal "points", precision: 6, scale: 1, null: false
    t.integer "sequence", null: false
    t.integer "slot", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["performance_id", "sequence"], name: "index_lineup_slots_on_performance_id_and_sequence", unique: true
    t.index ["performance_id"], name: "index_lineup_slots_on_performance_id"
  end

  create_table "owners", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_owners_on_name", unique: true
  end

  create_table "performances", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "game_id", null: false
    t.bigint "owner_id", null: false
    t.decimal "points", precision: 6, scale: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "owner_id"], name: "index_performances_on_game_id_and_owner_id", unique: true
    t.index ["game_id"], name: "index_performances_on_game_id"
    t.index ["owner_id"], name: "index_performances_on_owner_id"
  end

  create_table "playoff_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "season_id", null: false
    t.integer "start_week", null: false
    t.integer "team_count", null: false
    t.integer "tier", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["season_id", "tier"], name: "index_playoff_formats_on_season_id_and_tier", unique: true
    t.index ["season_id"], name: "index_playoff_formats_on_season_id"
  end

  create_table "roster_formats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "season_id", null: false
    t.string "slots", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.index ["season_id"], name: "index_roster_formats_on_season_id", unique: true
  end

  create_table "seasons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["year"], name: "index_seasons_on_year", unique: true
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "owner_id", null: false
    t.bigint "season_id", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id", "season_id"], name: "index_teams_on_owner_id_and_season_id", unique: true
    t.index ["owner_id"], name: "index_teams_on_owner_id"
    t.index ["season_id"], name: "index_teams_on_season_id"
  end

  add_foreign_key "games", "seasons"
  add_foreign_key "lineup_slots", "performances"
  add_foreign_key "performances", "games"
  add_foreign_key "performances", "owners"
  add_foreign_key "playoff_formats", "seasons"
  add_foreign_key "roster_formats", "seasons"
  add_foreign_key "teams", "owners"
  add_foreign_key "teams", "seasons"
end
