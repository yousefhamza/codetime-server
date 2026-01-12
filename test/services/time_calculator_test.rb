# frozen_string_literal: true

require "test_helper"
require "ostruct"

class TimeCalculatorTest < ActiveSupport::TestCase
  # Test 1: Empty events returns 0 minutes
  test "empty events returns 0 minutes" do
    events = []
    calculator = TimeCalculator.new(events)

    assert_equal 0, calculator.calculate
  end

  # Test 2: Single event returns 1 minute (SINGLE_EVENT_CREDIT)
  test "single event returns 1 minute" do
    events = [mock_event(time: Time.parse("2024-01-15 09:00:00"))]
    calculator = TimeCalculator.new(events)

    assert_equal 1, calculator.calculate
  end

  # Test 3: Two events 1 minute apart returns 1 minute
  # (1 min gap + 0.5 min credit = 1.5, floors to 1)
  test "two events 1 minute apart returns 1 minute" do
    events = [
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:01:00"))
    ]
    calculator = TimeCalculator.new(events)

    assert_equal 1, calculator.calculate
  end

  # Test 4: Two events 2 minutes apart returns 2 minutes
  # (2 min gap + 0.5 min credit = 2.5, floors to 2)
  test "two events 2 minutes apart returns 2 minutes" do
    events = [
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:02:00"))
    ]
    calculator = TimeCalculator.new(events)

    assert_equal 2, calculator.calculate
  end

  # Test 5: Two events 6 minutes apart (outside timeout) returns 0 minutes
  # (gap > 5 min timeout, only 0.5 min credit = 0)
  test "two events 6 minutes apart returns 0 minutes" do
    events = [
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:06:00"))
    ]
    calculator = TimeCalculator.new(events)

    assert_equal 0, calculator.calculate
  end

  # Test 6: Two events exactly at 5 min boundary returns 5 minutes
  # (edge case: gap == timeout is included)
  test "two events exactly at 5 minute boundary returns 5 minutes" do
    events = [
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:05:00"))
    ]
    calculator = TimeCalculator.new(events)

    # 5 min gap + 0.5 min credit = 5.5, floors to 5
    assert_equal 5, calculator.calculate
  end

  # Test 7: Mixed gaps scenario from spec section 6
  # Events at 09:00, 09:01:30, 09:03, 09:15, 09:16, 09:17:30
  # Expected: 6 minutes (1.5+1.5+0+1+1.5 = 5.5 + 0.5 = 6 min)
  test "mixed gaps scenario returns 6 minutes" do
    events = [
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:01:30")),
      mock_event(time: Time.parse("2024-01-15 09:03:00")),
      mock_event(time: Time.parse("2024-01-15 09:15:00")),  # 12 min gap - exceeds timeout
      mock_event(time: Time.parse("2024-01-15 09:16:00")),
      mock_event(time: Time.parse("2024-01-15 09:17:30"))
    ]
    calculator = TimeCalculator.new(events)

    # Gap analysis:
    # 09:00 -> 09:01:30 = 1.5 min (within timeout, count it)
    # 09:01:30 -> 09:03 = 1.5 min (within timeout, count it)
    # 09:03 -> 09:15 = 12 min (exceeds timeout, don't count)
    # 09:15 -> 09:16 = 1 min (within timeout, count it)
    # 09:16 -> 09:17:30 = 1.5 min (within timeout, count it)
    # Total gaps: 1.5 + 1.5 + 0 + 1 + 1.5 = 5.5 min
    # Add last event credit: 5.5 + 0.5 = 6.0 min
    # Floor: 6 minutes
    assert_equal 6, calculator.calculate
  end

  # Test 8: Events are sorted by event_time
  # Pass events out of order, verify correct calculation
  test "events are sorted by event_time for correct calculation" do
    # Same events as test 7 but in random order
    events = [
      mock_event(time: Time.parse("2024-01-15 09:15:00")),
      mock_event(time: Time.parse("2024-01-15 09:01:30")),
      mock_event(time: Time.parse("2024-01-15 09:17:30")),
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:03:00")),
      mock_event(time: Time.parse("2024-01-15 09:16:00"))
    ]
    calculator = TimeCalculator.new(events)

    # Should produce same result as sorted events
    assert_equal 6, calculator.calculate
  end

  # Test 9: Events filtered by time range
  # Events outside start/end time should be excluded
  test "events filtered by time range excludes events outside range" do
    events = [
      mock_event(time: Time.parse("2024-01-15 08:55:00")),  # Before range
      mock_event(time: Time.parse("2024-01-15 09:00:00")),  # Start of range
      mock_event(time: Time.parse("2024-01-15 09:02:00")),  # Within range
      mock_event(time: Time.parse("2024-01-15 09:10:00")),  # End of range
      mock_event(time: Time.parse("2024-01-15 09:15:00"))   # After range
    ]

    calculator = TimeCalculator.new(
      events,
      start_time: Time.parse("2024-01-15 09:00:00"),
      end_time: Time.parse("2024-01-15 09:10:00")
    )

    # Only events from 09:00 to 09:10 are included
    # Gap: 09:00 -> 09:02 = 2 min
    # Gap: 09:02 -> 09:10 = 8 min (exceeds timeout, don't count)
    # Total: 2 min + 0.5 min credit = 2.5, floors to 2
    assert_equal 2, calculator.calculate
  end

  # Test 10: Realistic coding session
  # 30 min session with regular activity (events every 2-3 minutes)
  test "realistic 30 minute coding session with regular activity" do
    base_time = Time.parse("2024-01-15 09:00:00")
    events = [
      mock_event(time: base_time),
      mock_event(time: base_time + 2.minutes),   # 2 min gap
      mock_event(time: base_time + 4.minutes),   # 2 min gap
      mock_event(time: base_time + 7.minutes),   # 3 min gap
      mock_event(time: base_time + 10.minutes),  # 3 min gap
      mock_event(time: base_time + 12.minutes),  # 2 min gap
      mock_event(time: base_time + 15.minutes),  # 3 min gap
      mock_event(time: base_time + 18.minutes),  # 3 min gap
      mock_event(time: base_time + 20.minutes),  # 2 min gap
      mock_event(time: base_time + 23.minutes),  # 3 min gap
      mock_event(time: base_time + 25.minutes),  # 2 min gap
      mock_event(time: base_time + 28.minutes),  # 3 min gap
      mock_event(time: base_time + 30.minutes)   # 2 min gap
    ]
    calculator = TimeCalculator.new(events)

    # All gaps are within timeout (all <= 5 min)
    # Total gaps: 2+2+3+3+2+3+3+2+3+2+3+2 = 30 min
    # Add last event credit: 30 + 0.5 = 30.5 min
    # Floor: 30 minutes
    assert_equal 30, calculator.calculate
  end

  # Additional edge case tests

  test "events with start_time only filters correctly" do
    events = [
      mock_event(time: Time.parse("2024-01-15 08:55:00")),
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:02:00"))
    ]

    calculator = TimeCalculator.new(
      events,
      start_time: Time.parse("2024-01-15 09:00:00")
    )

    # Only 09:00 and 09:02 included
    # Gap: 2 min + 0.5 min credit = 2.5, floors to 2
    assert_equal 2, calculator.calculate
  end

  test "events with end_time only filters correctly" do
    events = [
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:02:00")),
      mock_event(time: Time.parse("2024-01-15 09:10:00"))
    ]

    calculator = TimeCalculator.new(
      events,
      end_time: Time.parse("2024-01-15 09:05:00")
    )

    # Only 09:00 and 09:02 included
    # Gap: 2 min + 0.5 min credit = 2.5, floors to 2
    assert_equal 2, calculator.calculate
  end

  test "all events outside time range returns 0 minutes" do
    events = [
      mock_event(time: Time.parse("2024-01-15 08:00:00")),
      mock_event(time: Time.parse("2024-01-15 08:30:00"))
    ]

    calculator = TimeCalculator.new(
      events,
      start_time: Time.parse("2024-01-15 09:00:00"),
      end_time: Time.parse("2024-01-15 10:00:00")
    )

    assert_equal 0, calculator.calculate
  end

  test "single event within time range returns 1 minute" do
    events = [
      mock_event(time: Time.parse("2024-01-15 08:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:30:00")),
      mock_event(time: Time.parse("2024-01-15 11:00:00"))
    ]

    calculator = TimeCalculator.new(
      events,
      start_time: Time.parse("2024-01-15 09:00:00"),
      end_time: Time.parse("2024-01-15 10:00:00")
    )

    # Only one event (09:30) is within range
    assert_equal 1, calculator.calculate
  end

  test "gap exactly at timeout boundary is included" do
    events = [
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:05:00")),
      mock_event(time: Time.parse("2024-01-15 09:10:00"))
    ]
    calculator = TimeCalculator.new(events)

    # Both gaps are exactly 5 minutes (at the boundary)
    # 5 + 5 = 10 min + 0.5 credit = 10.5, floors to 10
    assert_equal 10, calculator.calculate
  end

  test "gap just over timeout is not included" do
    events = [
      mock_event(time: Time.parse("2024-01-15 09:00:00")),
      mock_event(time: Time.parse("2024-01-15 09:05:01"))  # 5 min 1 sec gap
    ]
    calculator = TimeCalculator.new(events)

    # Gap of 5:01 exceeds 5:00 timeout
    # Only last event credit: 0.5 min, floors to 0
    assert_equal 0, calculator.calculate
  end

  private

  def mock_event(time:)
    # Create a simple struct-like object that responds to event_time
    OpenStruct.new(event_time: time)
  end
end
