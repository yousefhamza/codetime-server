require "test_helper"

class EventLogTest < ActiveSupport::TestCase
  VALID_EVENT_TYPES = %w[
    activateFileChanged
    editorChanged
    fileAddedLine
    fileCreated
    fileEdited
    fileRemoved
    fileSaved
    changeEditorSelection
    changeEditorVisibleRanges
  ].freeze

  VALID_OPERATION_TYPES = %w[read write].freeze

  # Association Tests
  test "should belong to user" do
    event_log = event_logs(:one)
    assert_respond_to event_log, :user
    assert_instance_of User, event_log.user
  end

  test "should require user association" do
    event_log = EventLog.new(
      event_time: Time.current,
      event_type: "fileEdited",
      operation_type: "write"
    )
    assert_not event_log.valid?
    assert_includes event_log.errors[:user], "must exist"
  end

  # Presence Validations
  test "should require event_time" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      event_type: "fileEdited",
      operation_type: "write",
      event_time: nil
    )
    assert_not event_log.valid?
    assert_includes event_log.errors[:event_time], "can't be blank"
  end

  test "should require event_type" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      event_time: Time.current,
      operation_type: "write",
      event_type: nil
    )
    assert_not event_log.valid?
    assert_includes event_log.errors[:event_type], "can't be blank"
  end

  # Event Type Validation Tests
  test "should accept all valid event_types" do
    user = users(:one)
    VALID_EVENT_TYPES.each do |event_type|
      event_log = EventLog.new(
        user: user,
        event_time: Time.current,
        event_type: event_type,
        operation_type: "write"
      )
      assert event_log.valid?, "Event type '#{event_type}' should be valid. Errors: #{event_log.errors.full_messages}"
    end
  end

  test "should reject invalid event_type" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      event_time: Time.current,
      event_type: "invalidEventType",
      operation_type: "write"
    )
    assert_not event_log.valid?
    assert_includes event_log.errors[:event_type], "is not included in the list"
  end

  test "should reject empty string event_type" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      event_time: Time.current,
      event_type: "",
      operation_type: "write"
    )
    assert_not event_log.valid?
    assert event_log.errors[:event_type].any?, "Empty event_type should be invalid"
  end

  # Operation Type Validation Tests
  test "should accept valid operation_types" do
    user = users(:one)
    VALID_OPERATION_TYPES.each do |operation_type|
      event_log = EventLog.new(
        user: user,
        event_time: Time.current,
        event_type: "fileEdited",
        operation_type: operation_type
      )
      assert event_log.valid?, "Operation type '#{operation_type}' should be valid. Errors: #{event_log.errors.full_messages}"
    end
  end

  test "should reject invalid operation_type" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      event_time: Time.current,
      event_type: "fileEdited",
      operation_type: "invalidOperation"
    )
    assert_not event_log.valid?
    assert_includes event_log.errors[:operation_type], "is not included in the list"
  end

  test "should allow nil operation_type" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      event_time: Time.current,
      event_type: "fileEdited",
      operation_type: nil
    )
    assert event_log.valid?, "Nil operation_type should be valid. Errors: #{event_log.errors.full_messages}"
  end

  test "should allow blank operation_type" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      event_time: Time.current,
      event_type: "fileEdited",
      operation_type: ""
    )
    assert event_log.valid?, "Blank operation_type should be valid. Errors: #{event_log.errors.full_messages}"
  end

  # Valid EventLog Tests
  test "should be valid with all required attributes" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      event_time: Time.current,
      event_type: "fileEdited",
      operation_type: "write"
    )
    assert event_log.valid?
  end

  test "should be valid with all attributes" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      project: "my_project",
      language: "ruby",
      relative_file: "app/models/user.rb",
      absolute_file: "/home/user/project/app/models/user.rb",
      editor: "vscode",
      platform: "darwin",
      platform_arch: "arm64",
      event_time: Time.current,
      event_type: "fileEdited",
      operation_type: "write",
      git_origin: "https://github.com/user/project.git",
      git_branch: "main"
    )
    assert event_log.valid?
  end

  test "should save a valid event_log" do
    user = users(:one)
    event_log = EventLog.new(
      user: user,
      event_time: Time.current,
      event_type: "fileSaved",
      operation_type: "write"
    )
    assert event_log.save
  end

  # Test each valid event type explicitly
  test "should accept activateFileChanged event type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "activateFileChanged")
    event_log.valid?
    assert_not_includes event_log.errors[:event_type], "is not included in the list"
  end

  test "should accept editorChanged event type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "editorChanged")
    event_log.valid?
    assert_not_includes event_log.errors[:event_type], "is not included in the list"
  end

  test "should accept fileAddedLine event type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "fileAddedLine")
    event_log.valid?
    assert_not_includes event_log.errors[:event_type], "is not included in the list"
  end

  test "should accept fileCreated event type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "fileCreated")
    event_log.valid?
    assert_not_includes event_log.errors[:event_type], "is not included in the list"
  end

  test "should accept fileEdited event type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "fileEdited")
    event_log.valid?
    assert_not_includes event_log.errors[:event_type], "is not included in the list"
  end

  test "should accept fileRemoved event type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "fileRemoved")
    event_log.valid?
    assert_not_includes event_log.errors[:event_type], "is not included in the list"
  end

  test "should accept fileSaved event type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "fileSaved")
    event_log.valid?
    assert_not_includes event_log.errors[:event_type], "is not included in the list"
  end

  test "should accept changeEditorSelection event type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "changeEditorSelection")
    event_log.valid?
    assert_not_includes event_log.errors[:event_type], "is not included in the list"
  end

  test "should accept changeEditorVisibleRanges event type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "changeEditorVisibleRanges")
    event_log.valid?
    assert_not_includes event_log.errors[:event_type], "is not included in the list"
  end

  # Test operation types explicitly
  test "should accept read operation type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "fileEdited", operation_type: "read")
    event_log.valid?
    assert_not_includes event_log.errors[:operation_type], "is not included in the list"
  end

  test "should accept write operation type" do
    user = users(:one)
    event_log = EventLog.new(user: user, event_time: Time.current, event_type: "fileEdited", operation_type: "write")
    event_log.valid?
    assert_not_includes event_log.errors[:operation_type], "is not included in the list"
  end
end
