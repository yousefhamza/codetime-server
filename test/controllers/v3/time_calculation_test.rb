# frozen_string_literal: true

require "test_helper"

class V3::TimeCalculationTest < ActionDispatch::IntegrationTest
  # Freeze time to January 1st, 2025 at 6:00 PM
  FROZEN_TIME = Time.utc(2025, 1, 1, 18, 0, 0)
  TEST_DAY = Time.utc(2025, 1, 1, 0, 0, 0)

  setup do
    travel_to FROZEN_TIME
    @user = User.create!(email: "calc_test@example.com", token: "calc_test_token", name: "Calc Test")
  end

  teardown do
    travel_back
  end

  # ============================================
  # Basic Cases
  # ============================================

  test "empty events returns 0 minutes" do
    # No events created
    assert_equal 0, query_minutes(1440)
  end

  test "single event returns 1 minute" do
    create_event(time: TEST_DAY + 9.hours)

    # Single event gets SINGLE_EVENT_CREDIT (1 minute)
    assert_equal 1, query_minutes(1440)
  end

  # ============================================
  # Gap Calculations
  # ============================================

  test "two events 1 minute apart returns 1 minute" do
    create_event(time: TEST_DAY + 9.hours)
    create_event(time: TEST_DAY + 9.hours + 1.minute)

    # 1 min gap + 0.5 min credit = 1.5, floors to 1
    assert_equal 1, query_minutes(1440)
  end

  test "two events 2 minutes apart returns 2 minutes" do
    create_event(time: TEST_DAY + 9.hours)
    create_event(time: TEST_DAY + 9.hours + 2.minutes)

    # 2 min gap + 0.5 min credit = 2.5, floors to 2
    assert_equal 2, query_minutes(1440)
  end

  test "two events 6 minutes apart returns 0 minutes" do
    create_event(time: TEST_DAY + 9.hours)
    create_event(time: TEST_DAY + 9.hours + 6.minutes)

    # Gap exceeds 5 min timeout, only 0.5 min credit = 0
    assert_equal 0, query_minutes(1440)
  end

  # ============================================
  # Boundary Cases (5 minute timeout)
  # ============================================

  test "two events exactly at 5 minute boundary returns 5 minutes" do
    create_event(time: TEST_DAY + 9.hours)
    create_event(time: TEST_DAY + 9.hours + 5.minutes)

    # Gap == timeout is included
    # 5 min gap + 0.5 min credit = 5.5, floors to 5
    assert_equal 5, query_minutes(1440)
  end

  test "gap exactly at timeout boundary is included" do
    create_event(time: TEST_DAY + 9.hours)
    create_event(time: TEST_DAY + 9.hours + 5.minutes)
    create_event(time: TEST_DAY + 9.hours + 10.minutes)

    # Both gaps are exactly 5 minutes (at the boundary)
    # 5 + 5 = 10 min + 0.5 credit = 10.5, floors to 10
    assert_equal 10, query_minutes(1440)
  end

  test "gap just over timeout is not included" do
    create_event(time: TEST_DAY + 9.hours)
    create_event(time: TEST_DAY + 9.hours + 5.minutes + 1.second)

    # Gap of 5:01 exceeds 5:00 timeout
    # Only last event credit: 0.5 min, floors to 0
    assert_equal 0, query_minutes(1440)
  end

  # ============================================
  # Mixed Gaps (Spec Example - Section 6)
  # ============================================

  test "mixed gaps scenario from spec returns 6 minutes" do
    # Events at 09:00, 09:01:30, 09:03, 09:15, 09:16, 09:17:30
    base_time = TEST_DAY + 9.hours
    create_event(time: base_time)
    create_event(time: base_time + 90.seconds)
    create_event(time: base_time + 180.seconds)
    create_event(time: base_time + 15.minutes)  # 12 min gap - exceeds timeout
    create_event(time: base_time + 16.minutes)
    create_event(time: base_time + 17.minutes + 30.seconds)

    # Gap analysis:
    # 09:00 -> 09:01:30 = 1.5 min (within timeout, count it)
    # 09:01:30 -> 09:03 = 1.5 min (within timeout, count it)
    # 09:03 -> 09:15 = 12 min (exceeds timeout, don't count)
    # 09:15 -> 09:16 = 1 min (within timeout, count it)
    # 09:16 -> 09:17:30 = 1.5 min (within timeout, count it)
    # Total gaps: 1.5 + 1.5 + 0 + 1 + 1.5 = 5.5 min
    # Add last event credit: 5.5 + 0.5 = 6.0 min
    assert_equal 6, query_minutes(1440)
  end

  # ============================================
  # Sorting
  # ============================================

  test "events are sorted by event_time for correct calculation" do
    # Same events as spec example but in random order
    base_time = TEST_DAY + 9.hours
    create_event(time: base_time + 15.minutes)
    create_event(time: base_time + 90.seconds)
    create_event(time: base_time + 17.minutes + 30.seconds)
    create_event(time: base_time)
    create_event(time: base_time + 180.seconds)
    create_event(time: base_time + 16.minutes)

    # Should produce same result as sorted events
    assert_equal 6, query_minutes(1440)
  end

  # ============================================
  # Time Range Filtering
  # ============================================

  test "minutes parameter filters events by time range" do
    # Create events at different times
    create_event(time: TEST_DAY + 10.hours)  # 10:00 - within 8 hour window
    create_event(time: TEST_DAY + 10.hours + 2.minutes)  # 10:02
    create_event(time: TEST_DAY + 5.hours)   # 05:00 - outside 8 hour window (13h before frozen time)

    # Query for last 8 hours (480 minutes) - frozen at 18:00, so 10:00 onwards
    # Only events at 10:00 and 10:02 are within range
    # Gap: 2 min + 0.5 min credit = 2.5, floors to 2
    assert_equal 2, query_minutes(480)
  end

  test "events outside time range are excluded" do
    # Events before the query window
    create_event(time: TEST_DAY + 1.hour)  # 01:00 - way before query window
    create_event(time: TEST_DAY + 2.hours) # 02:00

    # Query for last 60 minutes (frozen at 18:00, so 17:00-18:00)
    # No events in range
    assert_equal 0, query_minutes(60)
  end

  # ============================================
  # Realistic Coding Session
  # ============================================

  test "realistic 30 minute coding session with regular activity" do
    base_time = TEST_DAY + 17.hours  # 5pm, within frozen time window

    # Events every 2-3 minutes for 30 minutes
    create_event(time: base_time)
    create_event(time: base_time + 2.minutes)
    create_event(time: base_time + 4.minutes)
    create_event(time: base_time + 7.minutes)
    create_event(time: base_time + 10.minutes)
    create_event(time: base_time + 12.minutes)
    create_event(time: base_time + 15.minutes)
    create_event(time: base_time + 18.minutes)
    create_event(time: base_time + 20.minutes)
    create_event(time: base_time + 23.minutes)
    create_event(time: base_time + 25.minutes)
    create_event(time: base_time + 28.minutes)
    create_event(time: base_time + 30.minutes)

    # All gaps are within timeout (all <= 5 min)
    # Total gaps: 2+2+3+3+2+3+3+2+3+2+3+2 = 30 min
    # Add last event credit: 30 + 0.5 = 30.5 min
    # Floor: 30 minutes
    assert_equal 30, query_minutes(1440)
  end

  test "coding session with idle break in the middle" do
    base_time = TEST_DAY + 17.hours

    # First burst of activity
    create_event(time: base_time)
    create_event(time: base_time + 2.minutes)
    create_event(time: base_time + 4.minutes)

    # 10 minute idle break (exceeds timeout)

    # Second burst of activity
    create_event(time: base_time + 14.minutes)
    create_event(time: base_time + 16.minutes)
    create_event(time: base_time + 18.minutes)

    # First burst: 2+2 = 4 min
    # Gap to second burst: 10 min (exceeds timeout, not counted)
    # Second burst: 2+2 = 4 min
    # Total: 8 min + 0.5 credit = 8.5, floors to 8
    assert_equal 8, query_minutes(1440)
  end

  private

  def create_event(time:, type: "fileEdited")
    @user.event_logs.create!(
      event_time: time,
      event_type: type,
      project: "test",
      language: "ruby",
      editor: "vscode",
      platform: "darwin",
      platform_arch: "arm64"
    )
  end

  def query_minutes(minutes_param)
    get v3_users_self_minutes_url,
        params: { minutes: minutes_param },
        headers: { "Authorization" => "Bearer #{@user.token}" }
    assert_response :ok
    response.parsed_body["minutes"]
  end
end
