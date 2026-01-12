class ApplicationController < ActionController::Base
  # Disable CSRF protection for API endpoints
  protect_from_forgery with: :null_session

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
