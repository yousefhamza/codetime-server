require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Presence Validations
  test "should require email" do
    user = User.new(token: "some_token", name: "Test User")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should require token" do
    # Test that token presence is validated on existing records (update context)
    # where the auto-generation callback doesn't run
    user = users(:one)
    user.token = nil
    assert_not user.valid?
    assert_includes user.errors[:token], "can't be blank"
  end

  test "should allow blank name" do
    user = User.new(email: "unique_name_test@example.com", token: "unique_token_name_test")
    assert user.valid?, "User should be valid without a name"
  end

  # Uniqueness Validations
  test "should require unique email" do
    existing_user = users(:one)
    user = User.new(email: existing_user.email, token: "new_unique_token")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "should require unique token" do
    existing_user = users(:one)
    user = User.new(email: "another_email@example.com", token: existing_user.token)
    assert_not user.valid?
    assert_includes user.errors[:token], "has already been taken"
  end

  test "email uniqueness should be case insensitive" do
    existing_user = users(:one)
    user = User.new(email: existing_user.email.upcase, token: "unique_case_token")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  # Association Tests
  test "should have many event_logs" do
    user = users(:one)
    assert_respond_to user, :event_logs
    assert_kind_of ActiveRecord::Associations::CollectionProxy, user.event_logs
  end

  test "should destroy associated event_logs when user is destroyed" do
    user = users(:one)
    event_log = event_logs(:one)
    assert_equal user, event_log.user

    event_log_id = event_log.id
    user.destroy

    assert_raises(ActiveRecord::RecordNotFound) do
      EventLog.find(event_log_id)
    end
  end

  # Token Auto-Generation Tests
  test "should auto-generate token when blank on create" do
    user = User.new(email: "autogenerate@example.com", name: "Auto Token User")
    user.token = nil  # Explicitly set to nil
    user.save!

    assert_not_nil user.token
    assert_not user.token.blank?
  end

  test "should auto-generate token when empty string on create" do
    user = User.new(email: "autogenerate_empty@example.com", name: "Auto Token User")
    user.token = ""  # Empty string
    user.save!

    assert_not_nil user.token
    assert_not user.token.blank?
  end

  test "should not overwrite token when already provided" do
    custom_token = "my_custom_token_12345"
    user = User.new(email: "custom_token@example.com", name: "Custom Token User", token: custom_token)
    user.save!

    assert_equal custom_token, user.token
  end

  test "auto-generated token should be unique" do
    user1 = User.create!(email: "user1_autogen@example.com", name: "User 1")
    user2 = User.create!(email: "user2_autogen@example.com", name: "User 2")

    assert_not_equal user1.token, user2.token
  end

  # Valid User Tests
  test "should be valid with all required attributes" do
    user = User.new(email: "valid@example.com", token: "valid_token_123", name: "Valid User")
    assert user.valid?
  end

  test "should save a valid user" do
    user = User.new(email: "saveable@example.com", token: "saveable_token_123", name: "Saveable User")
    assert user.save
  end
end
