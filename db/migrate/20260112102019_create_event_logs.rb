class CreateEventLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :event_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :project
      t.string :language
      t.string :relative_file
      t.string :absolute_file
      t.string :editor
      t.string :platform
      t.string :platform_arch
      t.datetime :event_time
      t.string :event_type
      t.string :operation_type
      t.string :git_origin
      t.string :git_branch

      t.timestamps
    end
    add_index :event_logs, [:user_id, :event_time]
  end
end
