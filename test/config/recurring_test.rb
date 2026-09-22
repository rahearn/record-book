require "test_helper"
require "fugit"

# config/recurring.yml is read by the Solid Queue supervisor rather than by
# the app, so a job renamed out from under it, or a schedule that does not
# parse, would first say so in production at whatever hour it was meant to
# run. Cheaper to hear it here.
class RecurringTest < ActiveSupport::TestCase
  SCHEDULE = Rails.root.join("config/recurring.yml")

  tasks = (YAML.load_file(SCHEDULE) || {}).fetch("production", {})

  test "production has recurring tasks to check" do
    assert tasks.any?, "expected #{SCHEDULE} to configure production tasks"
  end

  tasks.each do |name, task|
    test "#{name} is scheduled on something Solid Queue can parse" do
      assert Fugit.parse(task["schedule"]), "#{name}: #{task["schedule"].inspect} is not a schedule"
    end

    test "#{name} names work that exists" do
      if task["class"]
        job = task["class"].safe_constantize
        assert job, "#{name}: there is no #{task["class"]}"
        assert job < ActiveJob::Base, "#{name}: #{task["class"]} is not a job"
        assert job.public_method_defined?(:perform), "#{name}: #{task["class"]} cannot be performed"
      else
        assert task["command"].present?, "#{name} has neither a class nor a command"
      end
    end
  end

  test "the season import runs on Tuesday morning in the league's own time zone" do
    schedule = Fugit.parse(tasks.fetch("import_mfl_season").fetch("schedule"))

    assert_equal [ Time.utc(2026, 9, 22, 10), Time.utc(2026, 12, 22, 11) ],
                 [ Time.utc(2026, 9, 21), Time.utc(2026, 12, 21) ]
                   .map { |after| schedule.next_time(after).to_utc_time }
  end
end
