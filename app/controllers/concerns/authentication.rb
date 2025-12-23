module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_setup
    before_action :require_authentication
    before_action :check_session_timeout
    before_action :update_last_seen
    helper_method :authenticated?
  end

  private

  def authenticated?
    session[:authenticated] == true
  end

  def require_authentication
    unless authenticated?
      redirect_to login_path, alert: "Please log in to continue"
      nil
    end
  end

  def check_session_timeout
    return unless authenticated?
    return unless session[:last_seen_at].present?

    timeout_minutes = Setting.instance.session_timeout_minutes
    last_seen = session[:last_seen_at].to_time

    if last_seen < timeout_minutes.minutes.ago
      reset_session
      redirect_to login_path, alert: "Your session has expired. Please log in again."
      nil
    end
  end

  def update_last_seen
    return unless authenticated?
    session[:last_seen_at] = Time.current
  end

  def require_setup
    return if Setting.instance.setup_complete?
    return if env_auth_configured?
    redirect_to setup_path and return
  end

  def env_auth_configured?
    ENV["AUTH_USERNAME"].present? && ENV["AUTH_PASSWORD"].present?
  end
end
