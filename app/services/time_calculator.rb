# frozen_string_literal: true

class TimeCalculator
  IDLE_TIMEOUT_MS = 300_000        # 5 minutes in milliseconds
  SINGLE_EVENT_CREDIT_MS = 60_000  # 1 minute in milliseconds
  LAST_EVENT_CREDIT_MS = 30_000    # 30 seconds in milliseconds

  def initialize(events, start_time: nil, end_time: nil)
    @events = events
    @start_time = start_time
    @end_time = end_time
  end

  def calculate
    # 1. Filter events by time range (if specified)
    filtered_events = filter_by_time_range(@events)

    # 2. Sort by event_time ascending
    sorted_events = filtered_events.sort_by(&:event_time)

    # 3. Handle empty case
    return 0 if sorted_events.empty?

    # 4. Handle single event case
    return ms_to_minutes(SINGLE_EVENT_CREDIT_MS) if sorted_events.size == 1

    # 5. Sum gaps between consecutive events (if gap <= timeout)
    active_time_ms = sorted_events.each_cons(2).sum do |prev_event, curr_event|
      gap_ms = (curr_event.event_time - prev_event.event_time) * 1000
      gap_ms <= IDLE_TIMEOUT_MS ? gap_ms : 0
    end

    # 6. Add LAST_EVENT_CREDIT
    total_ms = active_time_ms + LAST_EVENT_CREDIT_MS

    # 7. Return floor(total_ms / 60000)
    ms_to_minutes(total_ms)
  end

  private

  def filter_by_time_range(events)
    events.select do |event|
      after_start = @start_time.nil? || event.event_time >= @start_time
      before_end = @end_time.nil? || event.event_time <= @end_time
      after_start && before_end
    end
  end

  def ms_to_minutes(milliseconds)
    (milliseconds / 60_000).floor
  end
end
