# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Record Book is the official history book of the ATO Delta fantasy football league — it will collect
stats and records across every era of the league and every backend it has run on. The intended design
is documented in [docs/initial_design.html](docs/initial_design.html), a self-contained, JS-rendered
mockup with mock data illustrating the target screens (home/league overview, per-owner profile,
per-season view, head-to-head comparisons, standings with "luck" and tier indicators). Open it in a
browser to see the UI direction — it is not wired to real data or to this Rails app.

Treat `docs/initial_design.html` as the spec for screens not yet built.

## Architecture

The domain model is intentionally minimal and normalized for aggregate queries; a future loading
layer will import historical data into it:

- `Owner` (name, team_name) — a league member, constant across eras.
- `Season` (year) — one league year.
- `Game` (season, week, tier) — one regular-season matchup. `tier` is an enum: `unified` (single
  league, pre-2025), `premier`, `challenger`.
- `Performance` (game, owner, points) — one owner's score in a game; every game has exactly two.

All derived statistics live in `app/models/almanac.rb` (**not** `RecordBook` — that constant is the
application's own namespace from `config/application.rb`, so the stats facade is named `Almanac`).
`Almanac` loads every game once and computes: per-season standings (wins desc, points-for
tiebreak), career aggregates, "luck" (average points opponents scored below/above their own season
average), titles (first-place finishes excluding the Challenger tier), single-game extremes, and
the next season's promotion/relegation ladder (bottom 4 of Premier ↔ top 4 of Challenger). Value
objects live in `app/models/almanac/`. `Almanac.new` accepts `games:`, `promotion_count:`, and
`relegation_count:` keywords, which tests use to build small in-memory scenarios.

The League home page is `league#show` (root route), rendered from partials in `app/views/league/`.
Design tokens and component classes (`.blueprint`, `.tag-*`, `.btn`, `.table`) translated from the
design doc live in `app/assets/tailwind/application.css`.

`db/seeds.rb` generates a deterministic demo league (20 owners, 2011–2025) matching the design
mockup's data; it skips seeding when games already exist, and CI replants it in the test env.

## Stack

- Ruby 4.0.6, Rails 8.1
- PostgreSQL (via `pg`), including Solid Cache / Solid Queue / Solid Cable (DB-backed, no Redis)
- Server-rendered HTML with Propshaft + Tailwind CSS; Hotwire (Turbo + Stimulus) for interactivity,
  minimal hand-written JavaScript, no Node/npm toolchain (JS is managed via importmap-rails)
- Deployed as a Docker container via Kamal (see `config/deploy.yml`, `.kamal/`)

## Commands

Setup:
- `bin/setup` — installs gems, prepares the dev database, clears logs/tmp, then starts the dev server.
  Add `--skip-server` to skip the server, `--reset` to reset the database.
- `bin/dev` — starts the dev server (Rails server + Tailwind watcher, via `Procfile.dev`)

Testing:
- `bin/rails test` — run the full test suite (Minitest, parallelized across CPUs; see `test/test_helper.rb`)
- `bin/rails test test/models/foo_test.rb` — run a single test file
- `bin/rails test test/models/foo_test.rb:12` — run a single test at a line number
- `bin/rails test:system` — run system tests (Capybara + Selenium)
- `env RAILS_ENV=test bin/rails db:seed:replant` — reset the test DB and reseed (`db/seeds.rb`)

Linting/security:
- `bin/rubocop` — lint (rules inherited from `rubocop-rails-omakase`; house overrides go in `.rubocop.yml`)
- `bin/brakeman` — static security analysis
- `bin/bundler-audit` — audit gems for known CVEs
- `bin/importmap audit` — audit JS dependencies pinned via importmap

CI:
- `bin/ci` — runs the full CI pipeline locally, in the same order as GitHub Actions: setup, rubocop,
  bundler-audit, importmap audit, brakeman, `bin/rails test`, and a test-env seed replant. Defined in
  `config/ci.rb` using `ActiveSupport::ContinuousIntegration` — edit that file to add/reorder steps
  rather than editing `.github/workflows/ci.yml` directly (CI runs the equivalent steps as separate jobs).

Database:
- `bin/rails db:prepare` — create/migrate the dev database (idempotent)
- `bin/rails db:migrate` — run pending migrations
- The `cache`, `queue`, and `cable` databases (Solid Cache/Queue/Cable) are separate logical databases
  defined in `config/database.yml` with their own migration paths (`db/cache_migrate`, etc.) — don't mix
  their migrations into the primary `db/migrate`.

## Attribution

All commits and pull requests authored by Claude Code in this repository must be attributed to AI
(e.g. via a `Co-Authored-By: Claude` trailer on commits and a note in PR descriptions).
