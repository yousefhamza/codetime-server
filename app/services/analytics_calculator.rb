# frozen_string_literal: true

class AnalyticsCalculator
  IDLE_TIMEOUT_MS = 300_000      # 5 minutes in milliseconds
  LAST_EVENT_CREDIT_MS = 30_000  # 30 seconds in milliseconds

  def initialize(user, start_time, end_time)
    @user = user
    @start_time = start_time
    @end_time = end_time
  end

  def time_by_language
    calculate_time_by_attribute(:language)
  end

  def time_by_workspace
    calculate_time_by_attribute(:project)
  end

  def time_by_platform
    calculate_time_by_attribute(:platform)
  end

  def time_series_by_language
    events = fetch_events

    # Generate all dates in the range (oldest to newest, left to right on chart)
    start_date = @start_time.to_date
    end_date = @end_time.to_date
    all_dates = (start_date..end_date).to_a

    # Group events by date
    events_by_date = events.group_by { |e| e.event_time.to_date }

    # Return data for all dates, with empty hash for days without events
    all_dates.map do |date|
      daily_events = events_by_date[date] || []
      {
        date: date,
        data: daily_events.any? ? calculate_time_breakdown(daily_events, :language) : {}
      }
    end
  end

  private

  def fetch_events
    @user.event_logs
         .where(event_time: @start_time..@end_time)
         .order(event_time: :asc)
  end

  def calculate_time_by_attribute(attribute)
    events = fetch_events
    calculate_time_breakdown(events, attribute)
  end

  def calculate_time_breakdown(events, attribute)
    return {} if events.empty?

    time_by_attr = Hash.new(0)

    # Handle single event case - give credit to its attribute
    if events.size == 1
      attr_value = normalize_attribute(events.first.send(attribute))
      time_by_attr[attr_value] = ms_to_minutes(LAST_EVENT_CREDIT_MS)
      return time_by_attr
    end

    # Track time in milliseconds per attribute
    ms_by_attr = Hash.new(0)

    # Sum gaps between consecutive events
    events.each_cons(2) do |prev_event, curr_event|
      gap_ms = (curr_event.event_time - prev_event.event_time) * 1000

      if gap_ms <= IDLE_TIMEOUT_MS
        # Attribute gap time to the first event's attribute
        attr_value = normalize_attribute(prev_event.send(attribute))
        ms_by_attr[attr_value] += gap_ms
      end
    end

    # Add last event credit to the last event's attribute
    last_attr_value = normalize_attribute(events.last.send(attribute))
    ms_by_attr[last_attr_value] += LAST_EVENT_CREDIT_MS

    # Convert milliseconds to minutes
    ms_by_attr.each do |attr_value, ms|
      minutes = ms_to_minutes(ms)
      time_by_attr[attr_value] = minutes if minutes > 0
    end

    time_by_attr
  end

  def normalize_attribute(value)
    value.presence || "Unknown"
  end

  def ms_to_minutes(milliseconds)
    (milliseconds / 60_000).floor
  end
end
