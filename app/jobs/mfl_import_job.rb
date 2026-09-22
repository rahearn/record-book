# The scheduled twin of the `mfl:import` rake task: one season off
# MyFantasyLeague, written into the record book. `config/recurring.yml` runs it
# every Tuesday morning, which is once the week's last game has settled.
#
# Importing a whole season every week is deliberate. MFL moves scores for days
# after a week is played, and a stat correction can land long after that, so
# re-reconciling every week on record is the documented way to pick those up.
# It is safe out of season too: a matchup nobody has played yet carries no
# scores and is left out of the schedule, so the job writes nothing until the
# league starts playing.
class MflImportJob < ApplicationJob
  # MFL going quiet, throttling, or refusing a redirect is weather rather than
  # a fault in the record book, so the week is tried again before it is given
  # up on. Everything else — a season config that has fallen behind the
  # league, an owner the record book cannot find, a lineup deeper than the
  # roster allows — wants a human, and fails loudly into Solid Queue's failed
  # executions rather than being retried into the same wall.
  retry_on MyFantasyLeague::Client::Error, wait: :polynomially_longer, attempts: 3

  def perform(year, week: nil, tiers: nil)
    MyFantasyLeague::Import
      .new(year: year, report: ->(line) { Rails.logger.info("[mfl] #{line}") })
      .call(week: week, tiers: tiers)
  end
end
