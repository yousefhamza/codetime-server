# frozen_string_literal: true

require "test_helper"

class DashboardWorkflowTest < ActionDispatch::IntegrationTest
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
  # Complete Dashboard Workflow
  # ============================================

  test "complete workflow: login, view dashboard, switch periods, logout" do
    # Step 1: Create some coding activity data
    # Today's events
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby", project: "rails-app")
    create_event(user: @user, time: TEST_DAY + 9.hours + 2.minutes, language: "Ruby", project: "rails-app")
    create_event(user: @user, time: TEST_DAY + 10.hours, language: "Python", project: "ml-project")
    create_event(user: @user, time: TEST_DAY + 10.hours + 3.minutes, language: "Python", project: "ml-project")

    # Events from 3 days ago
    create_event(user: @user, time: FROZEN_TIME - 3.days, language: "JavaScript", project: "frontend-app")
    create_event(user: @user, time: FROZEN_TIME - 3.days + 4.minutes, language: "JavaScript", project: "frontend-app")

    # Events from 15 days ago
    create_event(user: @user, time: FROZEN_TIME - 15.days, language: "Go", project: "api-service")
    create_event(user: @user, time: FROZEN_TIME - 15.days + 5.minutes, language: "Go", project: "api-service")

    # Step 2: Try to access dashboard without login - should redirect
    get dashboard_root_url
    assert_redirected_to dashboard_login_path

    # Step 3: Go to login page
    get dashboard_login_url
    assert_response :success

    # Step 4: Submit login with valid token
    post dashboard_login_url, params: { token: @user.token }
    assert_redirected_to dashboard_root_path
    follow_redirect!
    assert_response :success
    assert_match(/Logged in successfully/, flash[:notice])

    # Step 5: View dashboard with default period (7d)
    get dashboard_root_url
    assert_response :success

    # Step 6: Switch to today period
    get dashboard_root_url, params: { period: "today" }
    assert_response :success

    # Step 7: Switch to 7d period
    get dashboard_root_url, params: { period: "7d" }
    assert_response :success

    # Step 8: Switch to 30d period
    get dashboard_root_url, params: { period: "30d" }
    assert_response :success

    # Step 9: Logout
    delete dashboard_logout_url
    assert_redirected_to dashboard_login_path
    follow_redirect!
    assert_response :success
    assert_match(/Logged out successfully/, flash[:notice])

    # Step 10: Verify can't access dashboard after logout
    get dashboard_root_url
    assert_redirected_to dashboard_login_path
  end

  # ============================================
  # Login with Different Users
  # ============================================

  test "workflow: switch between different user accounts" do
    user_two = users(:two)
    user_two.event_logs.destroy_all

    # Create events for both users
    create_event(user: @user, time: TEST_DAY + 9.hours, language: "Ruby")
    create_event(user: @user, time: TEST_DAY + 9.hours + 2.minutes, language: "Ruby")

    create_event(user: user_two, time: TEST_DAY + 9.hours, language: "Python")
    create_event(user: user_two, time: TEST_DAY + 9.hours + 3.minutes, language: "Python")

    # Login as user one
    post dashboard_login_url, params: { token: @user.token }
    assert_redirected_to dashboard_root_path
    follow_redirect!
    assert_response :success

    # View dashboard as user one
    get dashboard_root_url, params: { period: "today" }
    assert_response :success

    # Logout
    delete dashboard_logout_url
    assert_redirected_to dashboard_login_path

    # Login as user two
    post dashboard_login_url, params: { token: user_two.token }
    assert_redirected_to dashboard_root_path
    follow_redirect!
    assert_response :success

    # View dashboard as user two
    get dashboard_root_url, params: { period: "today" }
    assert_response :success

    # Logout user two
    delete dashboard_logout_url
    assert_redirected_to dashboard_login_path
  end

  # ============================================
  # Failed Login Attempts
  # ============================================

  test "workflow: failed login then successful login" do
    # Try with invalid token
    post dashboard_login_url, params: { token: "invalid_token" }
    assert_response :unprocessable_entity
    assert_nil session[:dashboard_user_id]

    # Dashboard should still be inaccessible
    get dashboard_root_url
    assert_redirected_to dashboard_login_path

    # Now login with valid token
    post dashboard_login_url, params: { token: @user.token }
    assert_redirected_to dashboard_root_path

    # Dashboard should be accessible
    get dashboard_root_url
    assert_response :success
  end

  # ============================================
  # Real-time Data Updates
  # ============================================

  test "workflow: dashboard shows newly logged events" do
    # Login
    post dashboard_login_url, params: { token: @user.token }
    follow_redirect!

    # View dashboard - no events yet
    get dashboard_root_url, params: { period: "today" }
    assert_response :success

    # Create new events via API
    post v3_users_event_log_url,
         params: {
           project: "new-project",
           language: "TypeScript",
           relative_file: "index.ts",
           absolute_file: "/path/to/index.ts",
           editor: "vscode",
           platform: "darwin",
           platform_arch: "arm64",
           event_time: (TEST_DAY + 14.hours).to_f * 1000,
           event_type: "fileEdited"
         },
         headers: { "Authorization" => "Bearer #{@user.token}" },
         as: :json
    assert_response :ok

    post v3_users_event_log_url,
         params: {
           project: "new-project",
           language: "TypeScript",
           relative_file: "index.ts",
           absolute_file: "/path/to/index.ts",
           editor: "vscode",
           platform: "darwin",
           platform_arch: "arm64",
           event_time: (TEST_DAY + 14.hours + 2.minutes).to_f * 1000,
           event_type: "fileEdited"
         },
         headers: { "Authorization" => "Bearer #{@user.token}" },
         as: :json
    assert_response :ok

    # View dashboard again - should now show the new events
    get dashboard_root_url, params: { period: "today" }
    assert_response :success
  end

  # ============================================
  # Session Persistence
  # ============================================

  test "workflow: session persists across multiple page views" do
    # Login
    post dashboard_login_url, params: { token: @user.token }
    follow_redirect!

    # Multiple requests should all succeed without re-login
    get dashboard_root_url
    assert_response :success

    get dashboard_root_url, params: { period: "today" }
    assert_response :success

    get dashboard_root_url, params: { period: "7d" }
    assert_response :success

    get dashboard_root_url, params: { period: "30d" }
    assert_response :success

    get dashboard_root_url
    assert_response :success
  end

  # ============================================
  # API and Dashboard Integration
  # ============================================

  test "workflow: log events via API and view in dashboard" do
    # Create events via API (simulating VS Code extension)
    events_data = [
      { time: TEST_DAY + 9.hours, language: "Ruby", project: "api-project" },
      { time: TEST_DAY + 9.hours + 1.minute, language: "Ruby", project: "api-project" },
      { time: TEST_DAY + 9.hours + 2.minutes, language: "Ruby", project: "api-project" },
      { time: TEST_DAY + 10.hours, language: "Python", project: "ml-project" },
      { time: TEST_DAY + 10.hours + 2.minutes, language: "Python", project: "ml-project" }
    ]

    events_data.each do |event|
      post v3_users_event_log_url,
           params: {
             project: event[:project],
             language: event[:language],
             relative_file: "test.rb",
             absolute_file: "/path/to/test.rb",
             editor: "vscode",
             platform: "darwin",
             platform_arch: "arm64",
             event_time: (event[:time].to_f * 1000).to_i,
             event_type: "fileEdited"
           },
           headers: { "Authorization" => "Bearer #{@user.token}" },
           as: :json
      assert_response :ok
    end

    # Verify events were created
    assert_equal 5, @user.event_logs.count

    # Login to dashboard
    post dashboard_login_url, params: { token: @user.token }
    follow_redirect!

    # View dashboard
    get dashboard_root_url, params: { period: "today" }
    assert_response :success
  end

  # ============================================
  # Edge Cases
  # ============================================

  test "workflow: handle empty activity data gracefully" do
    # Login with no events
    post dashboard_login_url, params: { token: @user.token }
    follow_redirect!

    # All period views should work with no data
    get dashboard_root_url
    assert_response :success

    get dashboard_root_url, params: { period: "today" }
    assert_response :success

    get dashboard_root_url, params: { period: "7d" }
    assert_response :success

    get dashboard_root_url, params: { period: "30d" }
    assert_response :success
  end

  test "workflow: already logged in user visiting login page" do
    # Login first
    post dashboard_login_url, params: { token: @user.token }
    follow_redirect!

    # Try to visit login page - should redirect to dashboard
    get dashboard_login_url
    assert_redirected_to dashboard_root_path
  end
end
