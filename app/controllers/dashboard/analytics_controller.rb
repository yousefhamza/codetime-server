# frozen_string_literal: true

module Dashboard
  class AnalyticsController < ApplicationController
    include DashboardAuthenticatable

    layout "dashboard"

    def show
      @period = params[:period] || "7d"
      start_time = calculate_start_time(@period)
      end_time = Time.current

      calculator = AnalyticsCalculator.new(current_dashboard_user, start_time, end_time)

      @language_data = calculator.time_by_language
      @workspace_data = calculator.time_by_workspace
      @platform_data = calculator.time_by_platform
      @time_series_data = calculator.time_series_by_language

      @total_minutes = @language_data.values.sum
    end

    private

    def calculate_start_time(period)
      case period
      when "today"
        Time.current.beginning_of_day
      when "7d"
        7.days.ago.beginning_of_day
      when "30d"
        30.days.ago.beginning_of_day
      else
        7.days.ago.beginning_of_day
      end
    end
  end
end
