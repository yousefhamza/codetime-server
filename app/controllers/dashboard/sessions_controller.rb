# frozen_string_literal: true

module Dashboard
  class SessionsController < ApplicationController
    layout "dashboard"

    def new
      redirect_to dashboard_root_path if session[:dashboard_user_id]
    end

    def create
      token = params[:token].to_s.strip
      user = User.find_by(token: token)

      if user
        session[:dashboard_user_id] = user.id
        redirect_to dashboard_root_path, notice: "Logged in successfully"
      else
        flash.now[:alert] = "Invalid token"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      session.delete(:dashboard_user_id)
      redirect_to dashboard_login_path, notice: "Logged out successfully"
    end
  end
end
