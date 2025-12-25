class Setting < ApplicationRecord
  has_secure_password :auth_password, validations: false

  validates :default_view_months, presence: true, inclusion: { in: [ 1, 3, 6 ] }
  validates :session_timeout_minutes, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :auth_username, presence: true, if: :auth_password_digest?
  validates :auth_password, length: { minimum: 8 }, if: -> { auth_password.present? }

  def self.instance
    first_or_create!(default_view_months: 3)
  end

  def setup_complete?
    auth_username.present? && auth_password_digest.present?
  end

  private

  def auth_password_digest?
    auth_password_digest.present?
  end
end
