class Setting < ApplicationRecord
  SINGLETON_GUARD = 1

  has_secure_password :auth_password, validations: false

  attr_readonly :singleton_guard

  validates :singleton_guard, inclusion: { in: [ SINGLETON_GUARD ] }
  validates :default_view_months, presence: true, inclusion: { in: [ 1, 3, 6 ] }
  validates :session_timeout_minutes, presence: true,
            numericality: {
              only_integer: true,
              greater_than: 0,
              less_than_or_equal_to: 1440,
              message: "must be between 1 and 1440 minutes (24 hours)"
            }
  validates :auth_username, presence: true, if: :auth_password_digest?
  validates :auth_password, length: { minimum: 8 }, if: -> { auth_password.present? }

  def self.instance
    find_by!(singleton_guard: SINGLETON_GUARD)
  end

  def self.ensure_instance!
    find_or_create_by!(singleton_guard: SINGLETON_GUARD) do |setting|
      setting.default_view_months = 3
      setting.session_timeout_minutes = 30
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def setup_complete?
    auth_username.present? && auth_password_digest.present?
  end

  private

  def auth_password_digest?
    auth_password_digest.present?
  end
end
