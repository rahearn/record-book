# Record Book

This application is the official history book of the ATO Delta fantasy football league. It collects stats and records across every era of the league and every backend.

## Design

The design doc is given by [docs/record_book_design.html](./docs/record_book_design.html).

## Implementation

* Ruby 4.0.6
* Ruby on Rails 8.1
* Server-rendered HTML, minimal javascript
* Tailwind CSS
* Full test coverage

## Todo:

Prod data import:

* LineupSlots (import players)
* Players (import players)
  * Potential issue: positions list could change season to season
  * Obvious issue: nfl team definitely changes season to season

### Done

* Teams (import teams from old history project csv)
* Games (import matchups)
* Performances (import matchups)
