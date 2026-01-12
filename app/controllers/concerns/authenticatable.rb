# frozen_string_literal: true

module Authenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = extract_bearer_token
    @current_user = User.find_by(token: token) if token.present?

    unless @current_user
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def extract_bearer_token
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")

    auth_header.split(" ", 2).last
  end

  def current_user
    @current_user
  end
end
