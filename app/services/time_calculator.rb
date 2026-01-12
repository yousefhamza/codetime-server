# frozen_string_literal: true

class TimeCalculator
  IDLE_TIMEOUT_MS = 300_000        # 5 minutes in milliseconds
  SINGLE_EVENT_CREDIT_MS = 60_000  # 1 minute in milliseconds
  LAST_EVENT_CREDIT_MS = 30_000    # 30 seconds in milliseconds

  def initialize(events)
    @events = events
  end

  def calculate
    # 3. Handle empty case
    return 0 if @events.empty?

    # 4. Handle single event case
    return ms_to_minutes(SINGLE_EVENT_CREDIT_MS) if @events.size == 1

    # 5. Sum gaps between consecutive events (if gap <= timeout)
    active_time_ms = @events.each_cons(2).sum do |prev_event, curr_event|
      gap_ms = (curr_event.event_time - prev_event.event_time) * 1000
      gap_ms <= IDLE_TIMEOUT_MS ? gap_ms : 0
    end

    # 6. Add LAST_EVENT_CREDIT
    total_ms = active_time_ms + LAST_EVENT_CREDIT_MS

    # 7. Return floor(total_ms / 60000)
    ms_to_minutes(total_ms)
  end

  private

  def ms_to_minutes(milliseconds)
    (milliseconds / 60_000).floor
  end
end
