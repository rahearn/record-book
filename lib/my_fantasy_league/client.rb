require "net/http"
require "json"

module MyFantasyLeague
  # A read-only client for one league on MyFantasyLeague's export API.
  #
  # Every request reads `https://host/year/export?TYPE=...&JSON=1`. Anything
  # naming a league belongs on the host that league lives on — `api` will
  # redirect there, but MFL is entitled to refuse the hop when it is busy — so
  # the host is read once out of the league's own record and used from then
  # on. MFL asks callers to name themselves and to leave a second between
  # requests, and answers 429 when they do not; both are honoured here.
  class Client
    Error = Class.new(StandardError)

    API_HOST = "api.myfantasyleague.com".freeze
    THROTTLE = 1.0
    ATTEMPTS = 4
    REDIRECTS = 3
    # Long enough to keep a season's player lookup to a single request, short
    # enough to stay well inside anyone's URL limits.
    PLAYER_BATCH = 300

    def initialize(year:, league_id:, user_agent:, throttle: THROTTLE)
      @year = year
      @league_id = league_id.to_s
      @user_agent = user_agent
      @throttle = throttle
      @host = API_HOST
    end

    # Names, divisions, roster shape, and the host the league answers on.
    def league
      @league ||= get("league").tap do |payload|
        @host = URI.parse(payload["baseURL"]).host if payload["baseURL"].present?
      end
    end

    # Every week's matchups with the scores they finished on. Weeks not yet
    # played come back with their scores empty.
    def schedule
      Array.wrap(get("schedule")["weeklySchedule"])
    end

    # The playoff brackets the league configured, championship and
    # consolation alike.
    def playoff_brackets
      Array.wrap(get("playoffBrackets")["playoffBracket"])
    end

    # One bracket's rounds, each with the games it was played over.
    def playoff_bracket(bracket_id)
      Array.wrap(get("playoffBracket", BRACKET_ID: bracket_id)["playoffRound"])
    end

    # Every franchise's starters and bench, for one week or for the whole
    # season. MFL answers the two under different keys; both are unwrapped to
    # the same list of weeks.
    def weekly_results(week: nil)
      return [ get("weeklyResults", W: week) ] if week

      Array.wrap(get("weeklyResults", key: "allWeeklyResults", W: "YTD")["weeklyResults"])
    end

    # Who the player ids in a week's results belong to. This one is about the
    # player database rather than the league, so it goes to `api` and is
    # asked in batches.
    def players(ids)
      ids.uniq.each_slice(PLAYER_BATCH).flat_map do |batch|
        Array.wrap(get("players", host: API_HOST, league: false,
                                  DETAILS: 1, PLAYERS: batch.join(","))["player"])
      end
    end

    private

    # The export API answers `{"<key>": ..., "version": ...}` on success and
    # `{"error": ...}` on failure, including for a league it will not show a
    # stranger — so a payload missing the key that was asked for is an error
    # however it is dressed up.
    def get(type, key: type, host: nil, league: true, **params)
      params = { TYPE: type, JSON: 1 }.merge(params)
      params[:L] = @league_id if league
      payload = fetch(URI::HTTPS.build(host: host || @host, path: "/#{@year}/export",
                                       query: URI.encode_www_form(params)))
      raise Error, "MFL #{type} failed: #{error_message(payload)}" if payload.key?("error")

      payload.fetch(key) { raise Error, "MFL #{type} answered without any #{key}" }
    end

    def error_message(payload)
      error = payload["error"]
      error.is_a?(Hash) ? error["$t"] : error
    end

    # Retries what is worth retrying — MFL's throttle, and its occasional bad
    # minute — and gives up on everything else, since a wrong league id or a
    # league that will not be shared does not come right on a second ask.
    def fetch(uri)
      attempt = 0
      begin
        attempt += 1
        response = nil
        response = follow(uri)
        return parse(response) if response.is_a?(Net::HTTPSuccess)

        raise Error, "MFL answered #{response.code} for #{uri}"
      rescue Error, Timeout::Error, SystemCallError, Net::HTTPBadResponse, IOError
        raise if attempt >= ATTEMPTS || !retryable?(response)

        sleep(@throttle * (2**attempt))
        retry
      end
    end

    # A connection that never answered is worth another go, as is a throttle
    # or a server that fell over.
    def retryable?(response)
      response.nil? ||
        response.is_a?(Net::HTTPTooManyRequests) ||
        response.is_a?(Net::HTTPServerError)
    end

    def follow(uri)
      REDIRECTS.times do
        response = request(uri)
        return response unless response.is_a?(Net::HTTPRedirection) && response["location"]

        uri = URI.join(uri, response["location"])
      end
      raise Error, "MFL redirected more than #{REDIRECTS} times"
    end

    def request(uri)
      pause
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 60) do |http|
        http.request(Net::HTTP::Get.new(uri, "User-Agent" => @user_agent, "Accept" => "application/json"))
      end
    end

    # MFL serves UTF-8 without always saying so, and one apostrophe in a
    # player's name is enough for that to matter.
    def parse(response)
      JSON.parse(response.body.dup.force_encoding(Encoding::UTF_8))
    rescue JSON::ParserError => error
      raise Error, "MFL sent something that is not JSON: #{error.message}"
    end

    def pause
      elapsed = @last_request && Process.clock_gettime(Process::CLOCK_MONOTONIC) - @last_request
      sleep(@throttle - elapsed) if elapsed && elapsed < @throttle
      @last_request = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
