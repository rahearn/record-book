ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Empty the league in foreign-key order, for tests of the no-data state.
    def wipe_league_data
      LineupSlot.delete_all
      Player.delete_all
      Performance.delete_all
      PlayoffFormat.delete_all
      RosterFormat.delete_all
      Team.delete_all
      Game.delete_all
      Season.delete_all
      Owner.delete_all
    end
  end
end
