# frozen_string_literal: true

require "test_helper"

class AnalyticsCalculatorTest < ActiveSupport::TestCase
  # Freeze time to January 1st, 2025 at 6:00 PM for all tests
  FROZEN_TIME = Time.utc(2025, 1, 1, 18, 0, 0)
  TEST_DAY = Time.utc(2025, 1, 1, 0, 0, 0)

  setup do
    travel_to FROZEN_TIME
    @user = users(:one)
    @user.event_logs.destroy_all
  end

  teardown do
    travel_back
  end

  # Helper to create events easily
  def create_event(user:, time:, language: "Ruby", project: "test-project", platform: "macOS")
    EventLog.create!(
      user: user,
      event_time: time,
      event_type: "fileEdited",
      language: language,
      project: project,
      platform: platform,
      relative_file: "test.rb",
      absolute_file: "/path/to/test.rb",
      editor: "vscode",
      platform_arch: "arm64"
    )
  end

  # ============================================
  # Empty Events Tests
  # ============================================

  test "empty events returns empty hash for time_by_language" do
    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    assert_equal({}, calculator.time_by_language)
  end

  test "empty events returns empty hash for time_by_workspace" do
    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    assert_equal({}, calculator.time_by_workspace)
  end

  test "empty events returns empty hash for time_by_platform" do
    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    assert_equal({}, calculator.time_by_platform)
  end

  test "empty events returns empty array for time_series_by_language" do
    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    assert_equal([], calculator.time_series_by_language)
  end

  # ============================================
  # Single Event Tests
  # ============================================

  test "single event gives last event credit (0 minutes since 30 sec < 1 min)" do
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    # Single event gets 30 second credit = 0 minutes (floored)
    assert_equal({ "Ruby" => 0 }, result)
  end

  test "single event time_by_workspace gives credit" do
    create_event(user: @user, time: TEST_DAY + 9.hours, project: "my-project")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_workspace

    assert_equal({ "my-project" => 0 }, result)
  end

  test "single event time_by_platform gives credit" do
    create_event(user: @user, time: TEST_DAY + 9.hours, platform: "darwin")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_platform

    assert_equal({ "darwin" => 0 }, result)
  end

  # ============================================
  # Multiple Events with Gaps < 5 Minutes
  # ============================================

  test "two events 2 minutes apart counts the gap" do
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 2.minutes, language: "Ruby")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    # 2 minute gap + 30 second credit = 2.5 minutes -> floor = 2
    assert_equal({ "Ruby" => 2 }, result)
  end

  test "three events 1 minute apart each" do
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 1.minute, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 2.minutes, language: "Ruby")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    # 1 + 1 minute gaps + 30 second credit = 2.5 minutes -> floor = 2
    assert_equal({ "Ruby" => 2 }, result)
  end

  test "events at exactly 5 minute gap are counted" do
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 5.minutes, language: "Ruby")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    # 5 minute gap (at exactly threshold) + 30 second credit = 5.5 -> floor = 5
    assert_equal({ "Ruby" => 5 }, result)
  end

  # ============================================
  # Multiple Events with Gaps > 5 Minutes (Should Not Count)
  # ============================================

  test "events with gap > 5 minutes does not count the gap" do
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 6.minutes, language: "Ruby")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    # 6 minute gap exceeds 5 min threshold, so gap = 0, only 30 second credit -> 0
    # The calculator excludes entries with 0 minutes, so result should be empty
    assert_equal({}, result)
  end

  test "mixed gaps - some within threshold, some exceeding" do
    # Events at 9:00, 9:02, 9:03, 9:15, 9:16
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 2.minutes, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 3.minutes, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 15.minutes, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 16.minutes, language: "Ruby")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    # Gap 1: 9:00 -> 9:02 = 2 min (counted)
    # Gap 2: 9:02 -> 9:03 = 1 min (counted)
    # Gap 3: 9:03 -> 9:15 = 12 min (SKIPPED - exceeds 5 min)
    # Gap 4: 9:15 -> 9:16 = 1 min (counted)
    # Total: 2 + 1 + 1 = 4 min + 30 sec credit = 4.5 -> floor = 4
    assert_equal({ "Ruby" => 4 }, result)
  end

  # ============================================
  # Time by Language with Multiple Languages
  # ============================================

  test "time_by_language with multiple languages" do
    # Ruby events: 9:00, 9:02
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 2.minutes, language: "Ruby")

    # Python events: 9:10, 9:12, 9:14
    create_event(user: @user, time: TEST_DAY + 9.hours + 10.minutes, language: "Python")
    create_event(user: @user, time: TEST_DAY + 9.hours + 12.minutes, language: "Python")
    create_event(user: @user, time: TEST_DAY + 9.hours + 14.minutes, language: "Python")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    # Ruby: 9:00 -> 9:02 = 2 min
    # Gap 9:02 -> 9:10 = 8 min (SKIPPED - exceeds 5 min)
    # Python: 9:10 -> 9:12 = 2 min, 9:12 -> 9:14 = 2 min = 4 min + 30 sec credit
    # Ruby gets 2 min from gap, Python gets 4 min + 0.5 credit = 4
    assert_equal 2, result["Ruby"]
    assert_equal 4, result["Python"]
  end

  test "time_by_language attributes gap to first event language" do
    # Ruby at 9:00, Python at 9:02 (within 5 min threshold)
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 2.minutes, language: "Python")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    # Gap 9:00 -> 9:02 = 2 min attributed to Ruby (first event)
    # Python gets last event credit = 30 sec -> 0 min
    assert_equal 2, result["Ruby"]
    assert_equal 0, result["Python"]
  end

  # ============================================
  # Time by Workspace with Multiple Projects
  # ============================================

  test "time_by_workspace with multiple projects" do
    # Project A events: 9:00, 9:03
    create_event(user: @user, time: TEST_DAY + 9.hours, project: "project-a")
    create_event(user: @user, time: TEST_DAY + 9.hours + 3.minutes, project: "project-a")

    # Project B events: 9:10, 9:11
    create_event(user: @user, time: TEST_DAY + 9.hours + 10.minutes, project: "project-b")
    create_event(user: @user, time: TEST_DAY + 9.hours + 11.minutes, project: "project-b")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_workspace

    # Project A: 3 min gap
    # Gap 9:03 -> 9:10 = 7 min (SKIPPED)
    # Project B: 1 min gap + 30 sec credit = 1.5 -> 1 min
    assert_equal 3, result["project-a"]
    assert_equal 1, result["project-b"]
  end

  # ============================================
  # Time by Platform
  # ============================================

  test "time_by_platform with multiple platforms" do
    # macOS events: 9:00, 9:04
    create_event(user: @user, time: TEST_DAY + 9.hours, platform: "darwin")
    create_event(user: @user, time: TEST_DAY + 9.hours + 4.minutes, platform: "darwin")

    # Linux events: 9:10, 9:12, 9:14
    create_event(user: @user, time: TEST_DAY + 9.hours + 10.minutes, platform: "linux")
    create_event(user: @user, time: TEST_DAY + 9.hours + 12.minutes, platform: "linux")
    create_event(user: @user, time: TEST_DAY + 9.hours + 14.minutes, platform: "linux")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_platform

    # darwin: 4 min gap
    # Gap 9:04 -> 9:10 = 6 min (SKIPPED)
    # linux: 2 + 2 = 4 min + 30 sec = 4.5 -> 4 min
    assert_equal 4, result["darwin"]
    assert_equal 4, result["linux"]
  end

  # ============================================
  # Time Series Breakdown by Day
  # ============================================

  test "time_series_by_language groups by date" do
    # Day 1: Dec 31
    day1 = Time.utc(2024, 12, 31, 9, 0, 0)
    create_event(user: @user, time: day1, language: "Ruby")
    create_event(user: @user, time: day1 + 2.minutes, language: "Ruby")

    # Day 2: Jan 1
    day2 = Time.utc(2025, 1, 1, 9, 0, 0)
    create_event(user: @user, time: day2, language: "Python")
    create_event(user: @user, time: day2 + 3.minutes, language: "Python")

    calculator = AnalyticsCalculator.new(@user, day1.beginning_of_day, FROZEN_TIME)
    result = calculator.time_series_by_language

    assert_equal 2, result.length

    day1_entry = result.find { |e| e[:date] == Date.new(2024, 12, 31) }
    day2_entry = result.find { |e| e[:date] == Date.new(2025, 1, 1) }

    assert_not_nil day1_entry
    assert_not_nil day2_entry

    # Day 1: Ruby 2 min gap + 30 sec = 2.5 -> 2 min
    assert_equal({ "Ruby" => 2 }, day1_entry[:data])

    # Day 2: Python 3 min gap + 30 sec = 3.5 -> 3 min
    assert_equal({ "Python" => 3 }, day2_entry[:data])
  end

  test "time_series_by_language with multiple languages on same day" do
    day = TEST_DAY + 9.hours

    # Ruby events
    create_event(user: @user, time: day, language: "Ruby")
    create_event(user: @user, time: day + 2.minutes, language: "Ruby")

    # Python events (after 10 min gap - new session)
    create_event(user: @user, time: day + 12.minutes, language: "Python")
    create_event(user: @user, time: day + 14.minutes, language: "Python")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_series_by_language

    assert_equal 1, result.length
    day_entry = result.first

    # Ruby: 2 min gap
    # Gap 9:02 -> 9:12 = 10 min (SKIPPED)
    # Python: 2 min gap + 30 sec credit = 2.5 -> 2 min
    assert_equal 2, day_entry[:data]["Ruby"]
    assert_equal 2, day_entry[:data]["Python"]
  end

  # ============================================
  # Nil/Unknown Attribute Handling
  # ============================================

  test "nil language is normalized to Unknown" do
    # Create event with nil language by using direct database insert
    EventLog.create!(
      user: @user,
      event_time: TEST_DAY + 9.hours,
      event_type: "fileEdited",
      language: nil,
      project: "test-project",
      platform: "darwin",
      relative_file: "test",
      absolute_file: "/path/test",
      editor: "vscode",
      platform_arch: "arm64"
    )
    EventLog.create!(
      user: @user,
      event_time: TEST_DAY + 9.hours + 2.minutes,
      event_type: "fileEdited",
      language: nil,
      project: "test-project",
      platform: "darwin",
      relative_file: "test",
      absolute_file: "/path/test",
      editor: "vscode",
      platform_arch: "arm64"
    )

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    assert_equal({ "Unknown" => 2 }, result)
  end

  test "empty string language is normalized to Unknown" do
    EventLog.create!(
      user: @user,
      event_time: TEST_DAY + 9.hours,
      event_type: "fileEdited",
      language: "",
      project: "test-project",
      platform: "darwin",
      relative_file: "test",
      absolute_file: "/path/test",
      editor: "vscode",
      platform_arch: "arm64"
    )
    EventLog.create!(
      user: @user,
      event_time: TEST_DAY + 9.hours + 2.minutes,
      event_type: "fileEdited",
      language: "",
      project: "test-project",
      platform: "darwin",
      relative_file: "test",
      absolute_file: "/path/test",
      editor: "vscode",
      platform_arch: "arm64"
    )

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_language

    assert_equal({ "Unknown" => 2 }, result)
  end

  test "nil project is normalized to Unknown in time_by_workspace" do
    EventLog.create!(
      user: @user,
      event_time: TEST_DAY + 9.hours,
      event_type: "fileEdited",
      language: "Ruby",
      project: nil,
      platform: "darwin",
      relative_file: "test",
      absolute_file: "/path/test",
      editor: "vscode",
      platform_arch: "arm64"
    )
    EventLog.create!(
      user: @user,
      event_time: TEST_DAY + 9.hours + 2.minutes,
      event_type: "fileEdited",
      language: "Ruby",
      project: nil,
      platform: "darwin",
      relative_file: "test",
      absolute_file: "/path/test",
      editor: "vscode",
      platform_arch: "arm64"
    )

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    result = calculator.time_by_workspace

    assert_equal({ "Unknown" => 2 }, result)
  end

  # ============================================
  # Time Range Filtering
  # ============================================

  test "only includes events within specified time range" do
    # Event before range (should be excluded)
    create_event(user: @user, time: TEST_DAY - 1.day, language: "JavaScript")

    # Events within range
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 2.minutes, language: "Ruby")

    # Event after range (should be excluded)
    create_event(user: @user, time: TEST_DAY + 2.days, language: "Python")

    calculator = AnalyticsCalculator.new(@user, TEST_DAY, TEST_DAY + 1.day)
    result = calculator.time_by_language

    # Only Ruby events should be counted
    assert_equal({ "Ruby" => 2 }, result)
    assert_not result.key?("JavaScript")
    assert_not result.key?("Python")
  end

  # ============================================
  # User Isolation
  # ============================================

  test "only includes events for specified user" do
    user2 = users(:two)
    user2.event_logs.destroy_all

    # Events for user 1
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 2.minutes, language: "Ruby")

    # Events for user 2
    create_event(user: user2, time: TEST_DAY + 9.hours, language: "Python")
    create_event(user: user2, time: TEST_DAY + 9.hours + 3.minutes, language: "Python")

    calculator1 = AnalyticsCalculator.new(@user, TEST_DAY, FROZEN_TIME)
    calculator2 = AnalyticsCalculator.new(user2, TEST_DAY, FROZEN_TIME)

    result1 = calculator1.time_by_language
    result2 = calculator2.time_by_language

    # User 1 should only see Ruby
    assert_equal({ "Ruby" => 2 }, result1)

    # User 2 should only see Python
    assert_equal({ "Python" => 3 }, result2)
  end
end
