# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Record Book is the official history book of the ATO Delta fantasy football league — it will collect
stats and records across every era of the league and every backend it has run on. The intended design
is documented in [docs/initial_design.html](docs/initial_design.html), a self-contained, JS-rendered
mockup with mock data illustrating the target screens (home/league overview, per-owner profile,
per-season view, head-to-head comparisons, standings with "luck" and tier indicators). Open it in a
browser to see the UI direction — it is not wired to real data or to this Rails app.

The Rails application itself is currently just the generated skeleton (no models, controllers, or
routes beyond Rails defaults yet), so there is no existing domain architecture to describe — treat
`docs/initial_design.html` as the spec for what to build.

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
