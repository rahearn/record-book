# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Record Book is the official history book of the ATO Delta fantasy football league — it will collect
stats and records across every era of the league and every backend it has run on. The intended design
is documented in [docs/initial_design.html](docs/initial_design.html), a self-contained, JS-rendered
mockup with mock data illustrating the target screens (home/league overview, per-owner profile,
per-season view, head-to-head comparisons, standings with "luck" and tier indicators). Open it in a
browser to see the UI direction — it is not wired to real data or to this Rails app.

Treat `docs/record_book_design.html` as the spec for screens not yet built. New features not run through
a design phase will result in drift between the desired state of the app and the design spec.

## Architecture

The domain model is intentionally minimal and normalized for aggregate queries; a future loading
layer will import historical data into it:

- `Owner` (name) — a league member, constant across eras.
- `Season` (year) — one league year.
- `Team` (owner, season, name) — the team an owner fielded in one season; owners often rename
  season to season. `Owner#team_name` gives the most recent season's name (use it outside a season
  context); `Owner#team_name_in(year)` gives that season's name, falling back to the most recent.
- `Game` (season, week, tier, round_name) — one matchup. `tier` is an enum (`unified` pre-2025,
  `premier`, `challenger`; shared via the `Tiered` concern). A present `round_name` (e.g.
  "Semifinal") marks a playoff game; regular-season games have none.
- `PlayoffFormat` (season, tier, team_count, start_week) — playoff configuration per season *and*
  tier (Premier and Challenger differ, and both have changed over history). When a format exists,
  `Game` validates that games from `start_week` on carry a round name and earlier games don't.
- `Performance` (game, owner, points) — one owner's score in a game; every game has exactly two.

All `Almanac` statistics cover regular-season games only — playoff games are filtered out at load.

All derived statistics live in `app/models/almanac.rb` (**not** `RecordBook` — that constant is the
application's own namespace from `config/application.rb`, so the stats facade is named `Almanac`).
`Almanac` loads every game once and computes: per-season standings (wins desc, points-for
tiebreak), career aggregates, "luck" (average points opponents scored below/above their own season
average), titles (playoff championships won in the unified league or Premier tier — the single game
winner of the "Championship"-round game; tied or ambiguous finals crown no one), single-game
extremes, and the next season's promotion/relegation ladder. Relegation: bottom 4 of Premier by
record with total points as tiebreaker. Promotion: the Challenger regular-season points leader plus
the next three playoff finishers (finishing order: champion, runner-up, "Third Place"-round winner,
then its loser), with standings order filling gaps when playoff data is missing. Both tiers play a
third-place game as part of their playoff structure. Value
objects live in `app/models/almanac/`. `Almanac.new` accepts `games:`, `promotion_count:`, and
`relegation_count:` keywords, which tests use to build small in-memory scenarios.

The League home page is `league#show` (root route), rendered from partials in `app/views/league/`.
The Seasons page is `seasons#show` (`/seasons` and `/seasons/:year`, with a `tier` query param for
split seasons). The Owners page is `owners#show` (`/owners` defaults to the all-time leader,
`/owners/:id`, with a `season` query param selecting the week-by-week chart). The Head-to-head page
is `head_to_head#show` (`/head-to-head?a=&b=`, defaulting to the top two all-time owners). These
pages navigate via GET forms whose selects auto-submit through the `autosubmit` Stimulus
controller. Design tokens and component classes (`.blueprint`, `.tag-*`, `.btn`, `.seg`, `.table`,
zone shading) translated from the design doc live in `app/assets/tailwind/application.css`.
Avoid Tailwind arbitrary-value classes inside ERB expressions (e.g. `bg-[#hex]` in a ternary) —
the Tailwind scanner misses them; use theme utilities like `bg-neutral-400` instead.

The admin console is Active Admin 4, mounted at `/admin` and registered in `app/admin/` — one
resource file per model, plus a dashboard. It has no user model: `config.authentication_method`
points at `authenticate_admin!` (the `AdminAuthentication` concern on `ApplicationController`),
which checks a single HTTP basic username/password held in
`Rails.application.credentials.active_admin`. Comments are off, since they need an author.
Two things the console needs live outside `app/admin/`: `ApplicationRecord` opens every column and
association to Ransack (Active Admin's filters), and six models carry a `display_name` that Active
Admin uses for links, page titles, and select options. The array columns whose order matters
(`Player#positions`, `RosterFormat#slots`) are edited as one comma-separated text box and split back
apart by `ListColumnParams`. `Game` accepts nested `performances_attributes` so a matchup can be
written with both sides at once; `Performance` deliberately does *not* accept nested lineup slots,
because autosaving a whole lineup validates every persisted slot at once and a reshuffle trips the
per-performance `sequence` uniqueness — lineup slots are edited through their own resource.

`db/seeds.rb` generates a deterministic demo league (20 owners, 2011–2025) matching the design
mockup's data; it skips seeding when games already exist, and CI replants it in the test env.

## Stack

- Ruby 4.0.6, Rails 8.1
- PostgreSQL (via `pg`), including Solid Cache / Solid Queue / Solid Cable (DB-backed, no Redis)
- Server-rendered HTML with Propshaft + Tailwind CSS; Hotwire (Turbo + Stimulus) for interactivity,
  minimal hand-written JavaScript, no Node/npm toolchain (JS is managed via importmap-rails)
- Active Admin 4 for the admin console at `/admin` (Tailwind- and importmap-based, so it needs no
  Node either — `tailwind-active_admin.config.js` finds Active Admin's Tailwind plugin through
  Bundler rather than through `node_modules`)
- Deployed as a Docker container via Kamal (see `config/deploy.yml`, `.kamal/`)

## Commands

Setup:
- `bin/setup` — installs gems, prepares the dev database, clears logs/tmp, then starts the dev server.
  Add `--skip-server` to skip the server, `--reset` to reset the database.
- `bin/dev` — starts the dev server (Rails server + Tailwind watchers, via `Procfile.dev`)

Stylesheets (two separate Tailwind builds, so Active Admin's form styling stays off the public site):
- `bin/rails tailwindcss:build` — builds `app/assets/tailwind/application.css` into
  `app/assets/builds/tailwind.css`, then runs `active_admin:tailwindcss:build` for
  `app/assets/tailwind/active_admin.css` into `app/assets/builds/active_admin.css`
  (see `lib/tasks/active_admin.rake`). `assets:precompile` and `test:prepare` build both.
- The public layout links its stylesheets by name rather than with `stylesheet_link_tag :app`,
  which would also pull in the admin console's build.

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
