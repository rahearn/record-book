require "test_helper"

class MflImportJobTest < ActiveJob::TestCase
  # Stands in for the importer, which has a network on the other side of it.
  # What matters here is only what the job hands it and what it does with what
  # comes back, so the import itself is recorded rather than run.
  class StubImport
    attr_reader :built, :called

    def initialize(raising: nil)
      @raising = raising
      @called = []
    end

    def new(year:, report:)
      @built = { year: year, report: report }
      self
    end

    def call(week:, tiers:)
      @called << { week: week, tiers: tiers }
      raise @raising if @raising

      @built[:report].call("2026 week 3 premier: 10 games")
    end
  end

  test "a season is imported whole when no week is named" do
    import = StubImport.new
    perform(import, 2026)

    assert_equal 2026, import.built[:year]
    assert_equal [ { week: nil, tiers: nil } ], import.called
  end

  test "a single week of a single tier can be asked for" do
    import = StubImport.new
    perform(import, 2026, week: 7, tiers: [ "premier" ])

    assert_equal [ { week: 7, tiers: [ "premier" ] } ], import.called
  end

  test "the importer's report goes to the log" do
    log = StringIO.new
    with_logger(ActiveSupport::Logger.new(log)) { perform(StubImport.new, 2026) }

    assert_match(/\[mfl\] 2026 week 3 premier: 10 games/, log.string)
  end

  test "MyFantasyLeague going quiet is tried again" do
    import = StubImport.new(raising: MyFantasyLeague::Client::Error.new("429 from MFL"))

    assert_enqueued_with(job: MflImportJob) { perform(import, 2026) }
  end

  test "a season the record book cannot make sense of fails rather than retrying" do
    import = StubImport.new(raising: MyFantasyLeague::Import::Error.new("no owner named Nobody"))

    error = assert_raises(MyFantasyLeague::Import::Error) { perform(import, 2026) }
    assert_equal "no owner named Nobody", error.message
    assert_no_enqueued_jobs
  end

  private

  def with_logger(logger)
    was, Rails.logger = Rails.logger, logger
    yield
  ensure
    Rails.logger = was
  end

  def perform(import, year, **options)
    stub_const(MyFantasyLeague, :Import, import) { MflImportJob.perform_now(year, **options) }
  end
end
