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

### Done

* Players — dropped as a model; a player's name, NFL team and eligible positions
  are recorded on each LineupSlot, since all three are only true of one roster in
  one week
* Teams (import teams from old history project csv)
* Games (import matchups)
* Performances (import matchups)
