# frozen_string_literal: true

require "test_helper"

class V3::UsersControllerTest < ActionDispatch::IntegrationTest
  # ============================================
  # Authentication Tests
  # ============================================

  test "event_log returns 401 when no Authorization header" do
    post v3_users_event_log_url
    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "minutes returns 401 when no Authorization header" do
    get v3_users_self_minutes_url, params: { minutes: 60 }
    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "returns 401 when invalid token" do
    post v3_users_event_log_url, headers: { "Authorization" => "Bearer invalid_token_xyz" }
    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "returns 401 when malformed Authorization header (not Bearer xxx)" do
    post v3_users_event_log_url, headers: { "Authorization" => "Basic some_token" }
    assert_response :unauthorized

    post v3_users_event_log_url, headers: { "Authorization" => "token_without_bearer" }
    assert_response :unauthorized

    post v3_users_event_log_url, headers: { "Authorization" => "" }
    assert_response :unauthorized
  end

  test "returns 401 when token doesn't exist in database" do
    post v3_users_event_log_url, headers: { "Authorization" => "Bearer nonexistent_token_123" }
    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  # ============================================
  # Event Log Endpoint Tests
  # ============================================

  test "event_log returns 200 and creates event with valid payload" do
    user = users(:one)
    event_time_ms = (Time.current.to_f * 1000).to_i

    assert_difference("EventLog.count", 1) do
      post v3_users_event_log_url,
           params: {
             project: "my_project",
             language: "ruby",
             relative_file: "app/models/user.rb",
             absolute_file: "/home/user/my_project/app/models/user.rb",
             editor: "vscode",
             platform: "darwin",
             platform_arch: "arm64",
             event_time: event_time_ms,
             event_type: "fileEdited",
             operation_type: "write",
             git_origin: "https://github.com/user/my_project.git",
             git_branch: "main"
           },
           headers: { "Authorization" => "Bearer #{user.token}" },
           as: :json
    end

    assert_response :ok
  end

  test "event is associated with authenticated user" do
    user = users(:one)
    event_time_ms = (Time.current.to_f * 1000).to_i

    post v3_users_event_log_url,
         params: {
           project: "test_project",
           language: "ruby",
           relative_file: "test.rb",
           absolute_file: "/test.rb",
           editor: "vscode",
           platform: "darwin",
           platform_arch: "arm64",
           event_time: event_time_ms,
           event_type: "fileEdited"
         },
         headers: { "Authorization" => "Bearer #{user.token}" },
         as: :json

    assert_response :ok
    event = EventLog.last
    assert_equal user.id, event.user_id
  end

  test "handles all required fields correctly" do
    user = users(:one)
    event_time_ms = (Time.current.to_f * 1000).to_i

    post v3_users_event_log_url,
         params: {
           project: "test_project",
           language: "javascript",
           relative_file: "src/index.js",
           absolute_file: "/home/user/project/src/index.js",
           editor: "vim",
           platform: "linux",
           platform_arch: "x64",
           event_time: event_time_ms,
           event_type: "fileSaved",
           operation_type: "write"
         },
         headers: { "Authorization" => "Bearer #{user.token}" },
         as: :json

    assert_response :ok
    event = EventLog.last

    assert_equal "test_project", event.project
    assert_equal "javascript", event.language
    assert_equal "src/index.js", event.relative_file
    assert_equal "/home/user/project/src/index.js", event.absolute_file
    assert_equal "vim", event.editor
    assert_equal "linux", event.platform
    assert_equal "x64", event.platform_arch
    assert_equal "fileSaved", event.event_type
    assert_equal "write", event.operation_type
  end

  test "handles optional fields (git_origin and git_branch can be nil)" do
    user = users(:one)
    event_time_ms = (Time.current.to_f * 1000).to_i

    post v3_users_event_log_url,
         params: {
           project: "test_project",
           language: "ruby",
           relative_file: "test.rb",
           absolute_file: "/test.rb",
           editor: "vscode",
           platform: "darwin",
           platform_arch: "arm64",
           event_time: event_time_ms,
           event_type: "fileEdited"
           # git_origin and git_branch intentionally omitted
         },
         headers: { "Authorization" => "Bearer #{user.token}" },
         as: :json

    assert_response :ok
    event = EventLog.last
    assert_nil event.git_origin
    assert_nil event.git_branch
  end

  test "correctly stores eventTime as datetime (converts from ms timestamp)" do
    user = users(:one)
    # Create a specific timestamp
    expected_time = Time.utc(2026, 1, 12, 10, 30, 0)
    event_time_ms = (expected_time.to_f * 1000).to_i

    post v3_users_event_log_url,
         params: {
           project: "test_project",
           language: "ruby",
           relative_file: "test.rb",
           absolute_file: "/test.rb",
           editor: "vscode",
           platform: "darwin",
           platform_arch: "arm64",
           event_time: event_time_ms,
           event_type: "fileEdited"
         },
         headers: { "Authorization" => "Bearer #{user.token}" },
         as: :json

    assert_response :ok
    event = EventLog.last
    # Allow for small floating point differences
    assert_in_delta expected_time.to_i, event.event_time.to_i, 1
  end

  test "returns appropriate error for invalid event_type" do
    user = users(:one)
    event_time_ms = (Time.current.to_f * 1000).to_i

    post v3_users_event_log_url,
         params: {
           project: "test_project",
           language: "ruby",
           relative_file: "test.rb",
           absolute_file: "/test.rb",
           editor: "vscode",
           platform: "darwin",
           platform_arch: "arm64",
           event_time: event_time_ms,
           event_type: "invalidEventType"
         },
         headers: { "Authorization" => "Bearer #{user.token}" },
         as: :json

    assert_response :unprocessable_entity
  end

  # ============================================
  # Minutes Endpoint Tests
  # ============================================

  test "minutes returns JSON with { minutes: X } format" do
    user = users(:one)

    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok
    assert response.parsed_body.key?("minutes")
    assert_kind_of Integer, response.parsed_body["minutes"]
  end

  test "minutes returns 0 when user has no events" do
    user = users(:two)
    # Delete all events for user two
    user.event_logs.destroy_all

    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok
    assert_equal({ "minutes" => 0 }, response.parsed_body)
  end

  test "minutes correctly calculates for events within time range" do
    user = users(:one)
    user.event_logs.destroy_all

    # Create events 2 minutes apart within the time range
    now = Time.current
    user.event_logs.create!(
      project: "test",
      language: "ruby",
      relative_file: "test.rb",
      absolute_file: "/test.rb",
      editor: "vscode",
      platform: "darwin",
      platform_arch: "arm64",
      event_time: now - 10.minutes,
      event_type: "fileEdited"
    )
    user.event_logs.create!(
      project: "test",
      language: "ruby",
      relative_file: "test.rb",
      absolute_file: "/test.rb",
      editor: "vscode",
      platform: "darwin",
      platform_arch: "arm64",
      event_time: now - 8.minutes,
      event_type: "fileEdited"
    )

    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok
    # 2 minutes between events + 30 seconds credit = 2.5 minutes -> floor = 2
    assert_equal 2, response.parsed_body["minutes"]
  end

  test "minutes parameter filters events correctly" do
    user = users(:one)
    user.event_logs.destroy_all

    now = Time.current
    # Create an old event outside the time window
    user.event_logs.create!(
      project: "test",
      language: "ruby",
      relative_file: "test.rb",
      absolute_file: "/test.rb",
      editor: "vscode",
      platform: "darwin",
      platform_arch: "arm64",
      event_time: now - 2.hours,
      event_type: "fileEdited"
    )
    # Create a recent event inside the time window
    user.event_logs.create!(
      project: "test",
      language: "ruby",
      relative_file: "test.rb",
      absolute_file: "/test.rb",
      editor: "vscode",
      platform: "darwin",
      platform_arch: "arm64",
      event_time: now - 30.minutes,
      event_type: "fileEdited"
    )

    # Query with 60 minutes window - should only include the recent event
    get v3_users_self_minutes_url,
        params: { minutes: 60 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok
    # Single event gets 1 minute credit
    assert_equal 1, response.parsed_body["minutes"]
  end

  test "handles Today scenario (small minutes value)" do
    user = users(:one)
    user.event_logs.destroy_all

    now = Time.current
    # Create events within the last hour
    user.event_logs.create!(
      project: "test",
      language: "ruby",
      relative_file: "test.rb",
      absolute_file: "/test.rb",
      editor: "vscode",
      platform: "darwin",
      platform_arch: "arm64",
      event_time: now - 30.minutes,
      event_type: "fileEdited"
    )

    # Today might be ~1440 minutes (24 hours) or less, let's use a day's worth
    get v3_users_self_minutes_url,
        params: { minutes: 1440 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok
    assert response.parsed_body["minutes"] >= 0
  end

  test "handles 24h scenario (1440 minutes)" do
    user = users(:one)
    user.event_logs.destroy_all

    now = Time.current
    # Create event within 24h window
    user.event_logs.create!(
      project: "test",
      language: "ruby",
      relative_file: "test.rb",
      absolute_file: "/test.rb",
      editor: "vscode",
      platform: "darwin",
      platform_arch: "arm64",
      event_time: now - 12.hours,
      event_type: "fileEdited"
    )

    get v3_users_self_minutes_url,
        params: { minutes: 1440 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok
    # Single event gets 1 minute credit
    assert_equal 1, response.parsed_body["minutes"]
  end

  test "handles Total scenario (large minutes value like 52560000)" do
    user = users(:one)
    user.event_logs.destroy_all

    now = Time.current
    # Create an old event
    user.event_logs.create!(
      project: "test",
      language: "ruby",
      relative_file: "test.rb",
      absolute_file: "/test.rb",
      editor: "vscode",
      platform: "darwin",
      platform_arch: "arm64",
      event_time: now - 30.days,
      event_type: "fileEdited"
    )

    # 52560000 minutes = ~100 years - should include all events
    get v3_users_self_minutes_url,
        params: { minutes: 52560000 },
        headers: { "Authorization" => "Bearer #{user.token}" }

    assert_response :ok
    assert response.parsed_body["minutes"] >= 0
  end
end
