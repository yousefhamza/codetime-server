# frozen_string_literal: true

require "test_helper"

class Dashboard::SessionsControllerTest < ActionDispatch::IntegrationTest
  # Freeze time to January 1st, 2025 at 6:00 PM for all tests
  FROZEN_TIME = Time.utc(2025, 1, 1, 18, 0, 0)

  setup do
    travel_to FROZEN_TIME
    @user = users(:one)
  end

  teardown do
    travel_back
  end

  # ============================================
  # GET login page (new action)
  # ============================================

  test "GET login page renders successfully" do
    get dashboard_login_url
    assert_response :success
  end

  test "GET login page renders new template" do
    get dashboard_login_url
    assert_select "form" # Should have a login form
  end

  test "GET login page redirects to dashboard if already logged in" do
    # First log in
    post dashboard_login_url, params: { token: @user.token }
    assert_response :redirect

    # Now try to access login page again
    get dashboard_login_url
    assert_redirected_to dashboard_root_path
  end

  # ============================================
  # POST login (create action)
  # ============================================

  test "POST login with valid token creates session and redirects to dashboard" do
    post dashboard_login_url, params: { token: @user.token }

    assert_redirected_to dashboard_root_path
    assert_equal @user.id, session[:dashboard_user_id]
    follow_redirect!
    assert_match(/Logged in successfully/, flash[:notice])
  end

  test "POST login with valid token with whitespace trims and succeeds" do
    post dashboard_login_url, params: { token: "  #{@user.token}  " }

    assert_redirected_to dashboard_root_path
    assert_equal @user.id, session[:dashboard_user_id]
  end

  test "POST login with invalid token shows error" do
    post dashboard_login_url, params: { token: "invalid_token_xyz" }

    assert_response :unprocessable_entity
    assert_nil session[:dashboard_user_id]
    assert_match(/Invalid token/, flash[:alert])
  end

  test "POST login with empty token shows error" do
    post dashboard_login_url, params: { token: "" }

    assert_response :unprocessable_entity
    assert_nil session[:dashboard_user_id]
    assert_match(/Invalid token/, flash[:alert])
  end

  test "POST login with nil token shows error" do
    post dashboard_login_url, params: {}

    assert_response :unprocessable_entity
    assert_nil session[:dashboard_user_id]
  end

  test "POST login with another user token logs in as that user" do
    user_two = users(:two)

    post dashboard_login_url, params: { token: user_two.token }

    assert_redirected_to dashboard_root_path
    assert_equal user_two.id, session[:dashboard_user_id]
  end

  # ============================================
  # DELETE logout (destroy action)
  # ============================================

  test "DELETE logout clears session and redirects to login" do
    # First log in
    post dashboard_login_url, params: { token: @user.token }
    assert_equal @user.id, session[:dashboard_user_id]

    # Then log out
    delete dashboard_logout_url

    assert_redirected_to dashboard_login_path
    assert_nil session[:dashboard_user_id]
    follow_redirect!
    assert_match(/Logged out successfully/, flash[:notice])
  end

  test "DELETE logout works even if not logged in" do
    # Try to log out without being logged in
    delete dashboard_logout_url

    assert_redirected_to dashboard_login_path
    assert_nil session[:dashboard_user_id]
  end

  # ============================================
  # Session Persistence
  # ============================================

  test "session persists across requests after login" do
    # Log in
    post dashboard_login_url, params: { token: @user.token }
    assert_equal @user.id, session[:dashboard_user_id]

    # Make another request
    get dashboard_root_url
    assert_response :success
    assert_equal @user.id, session[:dashboard_user_id]
  end
end
