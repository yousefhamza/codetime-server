class EventLog < ApplicationRecord
  belongs_to :user

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

  validates :event_time, presence: true
  validates :event_type, presence: true, inclusion: { in: VALID_EVENT_TYPES }
  validates :operation_type, inclusion: { in: VALID_OPERATION_TYPES }, allow_blank: true

  scope :since, ->(start_time) { where("event_time >= ?", start_time).order(event_time: :asc) }
end
