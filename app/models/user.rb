class User < ApplicationRecord
  has_many :event_logs, dependent: :destroy

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  private

  def generate_token
    self.token = SecureRandom.hex(32) if token.blank?
  end
end
