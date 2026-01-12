# frozen_string_literal: true

class V3::UsersController < ApplicationController
  include Authenticatable

  # POST /v3/users/event-log
  # Accepts both camelCase (from VS Code extension) and snake_case params
  def event_log
    # Convert event_time from milliseconds to datetime
    event_time_ms = param_value(:event_time, :eventTime).to_i
    event_time = Time.at(event_time_ms / 1000.0).utc

    event = current_user.event_logs.build(
      project: params[:project],
      language: params[:language],
      relative_file: param_value(:relative_file, :relativeFile),
      absolute_file: param_value(:absolute_file, :absoluteFile),
      editor: params[:editor],
      platform: params[:platform],
      platform_arch: param_value(:platform_arch, :platformArch),
      event_time: event_time,
      event_type: param_value(:event_type, :eventType),
      operation_type: param_value(:operation_type, :operationType),
      git_origin: param_value(:git_origin, :gitOrigin),
      git_branch: param_value(:git_branch, :gitBranch)
    )

    if event.save
      head :ok
    else
      render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /v3/users/self/minutes
  def minutes
    minutes_param = params[:minutes].to_i
    start_time = Time.current - minutes_param.minutes

    events = current_user.event_logs.where("event_time >= ?", start_time)

    calculator = TimeCalculator.new(events, start_time: start_time, end_time: Time.current)
    calculated_minutes = calculator.calculate

    render json: { minutes: calculated_minutes }
  end

  private

  # Helper to accept both snake_case and camelCase parameter names
  def param_value(snake_key, camel_key)
    params[snake_key] || params[camel_key]
  end
end
