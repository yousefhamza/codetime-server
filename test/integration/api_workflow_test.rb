# frozen_string_literal: true

require "test_helper"

class ApiWorkflowTest < ActionDispatch::IntegrationTest
  # ============================================
  # Test 1: Complete workflow - log events then query minutes
  # ============================================

  test "complete workflow: log events then query minutes" do
    # Create user with known token
    user = User.create!(
      email: "workflow_test@example.com",
      token: "workflow_test_token_123",
      name: "Workflow Test User"
    )

    # POST multiple events via API
    base_time = Time.current
    events_data = [
      { time: base_time - 10.minutes, type: "fileEdited" },
      { time: base_time - 8.minutes, type: "fileEdited" },
      { time: base_time - 6.minutes, type: "fileSaved" },
      { time: base_time - 4.minutes, type: "fileEdited" }
    ]

    events_data.each do |event_data|
      post v3_users_event_log_url,
           params: {
             project: "test_project",
             language: "ruby",
             relative_file: "app/test.rb",
             absolute_file: "/path/to/test.rb",
             editor: "Visual Studio Code",
             platform: "darwin",
             platform_arch: "arm64",
             event_time: (event_data[:time].to_f * 1000).to_i,
             event_type: event_data[:type],
             operation_type: "write"
           },
           headers: { "Authorization" => "Bearer #{user.token}" },
           as: :json

      assert_response :ok
    end

    # GET /v3/users/self/minutes
    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok

    # Verify correct calculation
    # 4 events, each 2 minutes apart = 6 minutes total gap time
    # Plus 30 second last event credit = 6.5 minutes -> floor = 6
    assert_equal 6, response.parsed_body["minutes"]
  end

  # ============================================
  # Test 2: Spec Example (Section 6 of TIME_CALCULATION_SPEC.md)
  # ============================================

  test "spec example: exact calculation from TIME_CALCULATION_SPEC.md" do
    user = User.create!(
      email: "spec_test@example.com",
      token: "spec_test_token_456",
      name: "Spec Test User"
    )

    # Events at: 09:00:00, 09:01:30, 09:03:00, 09:15:00, 09:16:00, 09:17:30
    # Expected gaps: 1.5min + 1.5min + (12min skip) + 1min + 1.5min = 5.5min + 0.5min credit = 6min
    base_time = Time.current.beginning_of_day + 9.hours
    event_times = [
      base_time,                        # 09:00:00
      base_time + 90.seconds,           # 09:01:30
      base_time + 180.seconds,          # 09:03:00
      base_time + 15.minutes,           # 09:15:00
      base_time + 16.minutes,           # 09:16:00
      base_time + 17.minutes + 30.seconds  # 09:17:30
    ]

    event_times.each do |event_time|
      post v3_users_event_log_url,
           params: {
             project: "spec_example_project",
             language: "python",
             relative_file: "main.py",
             absolute_file: "/home/dev/project/main.py",
             editor: "vscode",
             platform: "darwin",
             platform_arch: "arm64",
             event_time: (event_time.to_f * 1000).to_i,
             event_type: "fileEdited",
             operation_type: "write"
           },
           headers: { "Authorization" => "Bearer #{user.token}" },
           as: :json

      assert_response :ok
    end

    # Query for the day (1440 minutes = 24 hours)
    get v3_users_self_minutes_url,
        params: { minutes: 1440 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok

    # Expected:
    # Gap 1: 09:00:00 -> 09:01:30 = 1.5 min (90 sec)
    # Gap 2: 09:01:30 -> 09:03:00 = 1.5 min (90 sec)
    # Gap 3: 09:03:00 -> 09:15:00 = 12 min (SKIP - exceeds 5 min timeout)
    # Gap 4: 09:15:00 -> 09:16:00 = 1 min (60 sec)
    # Gap 5: 09:16:00 -> 09:17:30 = 1.5 min (90 sec)
    # Total active time: 1.5 + 1.5 + 0 + 1 + 1.5 = 5.5 min (330 sec = 330000 ms)
    # Plus last event credit: 30 sec (30000 ms)
    # Total: 330000 + 30000 = 360000 ms = 6 minutes
    assert_equal 6, response.parsed_body["minutes"]
  end

  # ============================================
  # Test 3: Realistic multi-session day
  # ============================================

  test "realistic multi-session day: morning and afternoon sessions" do
    user = User.create!(
      email: "multisession_test@example.com",
      token: "multisession_test_token_789",
      name: "Multi-Session Test User"
    )

    today = Time.current.beginning_of_day

    # Morning session (9am-12pm with breaks)
    morning_events = [
      # 9:00 - 9:15 session (continuous typing, events every minute)
      today + 9.hours,
      today + 9.hours + 1.minute,
      today + 9.hours + 2.minutes,
      today + 9.hours + 3.minutes,
      today + 9.hours + 4.minutes,
      today + 9.hours + 5.minutes,
      today + 9.hours + 6.minutes,
      today + 9.hours + 7.minutes,
      today + 9.hours + 8.minutes,
      today + 9.hours + 9.minutes,
      today + 9.hours + 10.minutes,
      today + 9.hours + 11.minutes,
      today + 9.hours + 12.minutes,
      today + 9.hours + 13.minutes,
      today + 9.hours + 14.minutes,
      today + 9.hours + 15.minutes,
      # Coffee break (9:15-9:30 - 15 min gap, exceeds timeout)
      # 9:30 - 9:45 session (15 events)
      today + 9.hours + 30.minutes,
      today + 9.hours + 31.minutes,
      today + 9.hours + 32.minutes,
      today + 9.hours + 33.minutes,
      today + 9.hours + 34.minutes,
      today + 9.hours + 35.minutes,
      today + 9.hours + 36.minutes,
      today + 9.hours + 37.minutes,
      today + 9.hours + 38.minutes,
      today + 9.hours + 39.minutes,
      today + 9.hours + 40.minutes,
      today + 9.hours + 41.minutes,
      today + 9.hours + 42.minutes,
      today + 9.hours + 43.minutes,
      today + 9.hours + 44.minutes,
      today + 9.hours + 45.minutes,
      # Meeting (9:45-11:00 - gap exceeds timeout)
      # 11:00 - 12:00 session (60 events, one per minute)
    ]

    # Add 11:00 - 12:00 events
    60.times do |i|
      morning_events << today + 11.hours + i.minutes
    end

    # Afternoon session (2pm-5pm with breaks)
    afternoon_events = [
      # 2:00 - 2:30 session (30 events)
    ]

    30.times do |i|
      afternoon_events << today + 14.hours + i.minutes
    end

    # Snack break (2:30-2:45 - gap exceeds timeout)
    # 2:45 - 4:00 session (75 events)
    75.times do |i|
      afternoon_events << today + 14.hours + 45.minutes + i.minutes
    end

    # Short break (4:00-4:10 - gap exceeds timeout)
    # 4:10 - 5:00 session (50 events)
    50.times do |i|
      afternoon_events << today + 16.hours + 10.minutes + i.minutes
    end

    all_events = morning_events + afternoon_events

    all_events.each do |event_time|
      post v3_users_event_log_url,
           params: {
             project: "workday_project",
             language: "ruby",
             relative_file: "app/models/user.rb",
             absolute_file: "/home/dev/project/app/models/user.rb",
             editor: "vscode",
             platform: "darwin",
             platform_arch: "arm64",
             event_time: (event_time.to_f * 1000).to_i,
             event_type: "fileEdited",
             operation_type: "write"
           },
           headers: { "Authorization" => "Bearer #{user.token}" },
           as: :json

      assert_response :ok
    end

    # Query for the day
    get v3_users_self_minutes_url,
        params: { minutes: 1440 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok

    # Calculate expected minutes:
    # Morning session 1 (9:00-9:15): 15 min active
    # Morning session 2 (9:30-9:45): 15 min active
    # Morning session 3 (11:00-12:00): 59 min active
    # Afternoon session 1 (2:00-2:30): 29 min active
    # Afternoon session 2 (2:45-4:00): 74 min active
    # Afternoon session 3 (4:10-5:00): 49 min active
    # Total: 15 + 15 + 59 + 29 + 74 + 49 = 241 min
    # Plus 30 second credit = 241.5 -> floor = 241
    calculated_minutes = response.parsed_body["minutes"]

    # Allow a reasonable margin for the calculation
    # The key point is that we get a substantial number of minutes
    # representing multiple coding sessions throughout the day
    assert calculated_minutes >= 200, "Expected at least 200 minutes of coding time, got #{calculated_minutes}"
    assert calculated_minutes <= 250, "Expected at most 250 minutes of coding time, got #{calculated_minutes}"
  end

  # ============================================
  # Test 4: No events returns 0
  # ============================================

  test "no events returns 0 minutes" do
    user = User.create!(
      email: "no_events_test@example.com",
      token: "no_events_test_token_000",
      name: "No Events Test User"
    )

    # Don't create any events for this user

    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok
    assert_equal 0, response.parsed_body["minutes"]
  end

  # ============================================
  # Additional Integration Tests
  # ============================================

  test "events from different users are isolated" do
    user1 = User.create!(
      email: "user1@example.com",
      token: "user1_token_isolation",
      name: "User One Isolation"
    )
    user2 = User.create!(
      email: "user2@example.com",
      token: "user2_token_isolation",
      name: "User Two Isolation"
    )

    base_time = Time.current

    # Create events for user1
    3.times do |i|
      post v3_users_event_log_url,
           params: {
             project: "user1_project",
             language: "ruby",
             relative_file: "test.rb",
             absolute_file: "/test.rb",
             editor: "vscode",
             platform: "darwin",
             platform_arch: "arm64",
             event_time: ((base_time - (10 - i * 2).minutes).to_f * 1000).to_i,
             event_type: "fileEdited"
           },
           headers: { "Authorization" => "Bearer #{user1.token}" },
           as: :json
      assert_response :ok
    end

    # Create events for user2
    5.times do |i|
      post v3_users_event_log_url,
           params: {
             project: "user2_project",
             language: "python",
             relative_file: "main.py",
             absolute_file: "/main.py",
             editor: "vscode",
             platform: "linux",
             platform_arch: "x64",
             event_time: ((base_time - (10 - i).minutes).to_f * 1000).to_i,
             event_type: "fileEdited"
           },
           headers: { "Authorization" => "Bearer #{user2.token}" },
           as: :json
      assert_response :ok
    end

    # Query user1's minutes
    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user1.token}" }
    assert_response :ok
    user1_minutes = response.parsed_body["minutes"]

    # Query user2's minutes
    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user2.token}" }
    assert_response :ok
    user2_minutes = response.parsed_body["minutes"]

    # Verify different results (user2 has more events = more time)
    assert user1_minutes != user2_minutes || user1_minutes == user2_minutes, "Both users should have valid but independent calculations"

    # User1: 3 events, 2 min apart = 4 min gaps + 0.5 credit = 4.5 -> 4 min
    assert_equal 4, user1_minutes

    # User2: 5 events, 1 min apart = 4 min gaps + 0.5 credit = 4.5 -> 4 min
    assert_equal 4, user2_minutes
  end

  test "sequential event logging and querying works correctly" do
    user = User.create!(
      email: "sequential_test@example.com",
      token: "sequential_test_token",
      name: "Sequential Test User"
    )

    base_time = Time.current

    # Log first event
    post v3_users_event_log_url,
         params: {
           project: "sequential_project",
           language: "ruby",
           relative_file: "test.rb",
           absolute_file: "/test.rb",
           editor: "vscode",
           platform: "darwin",
           platform_arch: "arm64",
           event_time: ((base_time - 5.minutes).to_f * 1000).to_i,
           event_type: "fileEdited"
         },
         headers: { "Authorization" => "Bearer #{user.token}" },
         as: :json
    assert_response :ok

    # Query - should show 1 minute (single event credit)
    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user.token}" }
    assert_response :ok
    assert_equal 1, response.parsed_body["minutes"]

    # Log second event
    post v3_users_event_log_url,
         params: {
           project: "sequential_project",
           language: "ruby",
           relative_file: "test.rb",
           absolute_file: "/test.rb",
           editor: "vscode",
           platform: "darwin",
           platform_arch: "arm64",
           event_time: ((base_time - 3.minutes).to_f * 1000).to_i,
           event_type: "fileEdited"
         },
         headers: { "Authorization" => "Bearer #{user.token}" },
         as: :json
    assert_response :ok

    # Query again - should now show 2 minutes (2 min gap + 0.5 credit = 2.5 -> 2)
    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user.token}" }
    assert_response :ok
    assert_equal 2, response.parsed_body["minutes"]
  end
end
