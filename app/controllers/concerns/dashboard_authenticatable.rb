# frozen_string_literal: true

module DashboardAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :require_dashboard_login
    helper_method :current_dashboard_user
  end

  private

  def require_dashboard_login
    unless current_dashboard_user
      redirect_to dashboard_login_path, alert: "Please log in with your token"
    end
  end

  def current_dashboard_user
    @current_dashboard_user ||= User.find_by(id: session[:dashboard_user_id])
  end
end
