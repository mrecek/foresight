module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_setup
    before_action :require_authentication
    before_action :check_session_timeout
    before_action :update_last_seen
    helper_method :authenticated?, :test_mode_enabled?
  end

  private

  def authenticated?
    test_mode_enabled? || session[:authenticated] == true
  end

  def require_authentication
    return if test_mode_enabled?

    unless session[:authenticated] == true
      # Only show message if user tried to access a specific protected route
      # First-time visitors to the root get a clean login page
      if request.path == root_path
        redirect_to login_path
      else
        redirect_to login_path, flash: { info: "Please log in to continue" }
      end
      nil
    end
  end

  def check_session_timeout
    return if test_mode_enabled?
    return unless session[:authenticated] == true
    return unless session[:last_seen_at].present?

    timeout_minutes = Setting.instance.session_timeout_minutes
    last_seen = session[:last_seen_at].to_time

    if last_seen < timeout_minutes.minutes.ago
      reset_session
      redirect_to login_path, flash: { info: "Your session has expired. Please log in again." }
      nil
    end
  end

  def update_last_seen
    return if test_mode_enabled?
    return unless session[:authenticated] == true
    session[:last_seen_at] = Time.current
  end

  def require_setup
    return if test_mode_enabled?
    return if Setting.instance.setup_complete?
    return if env_auth_configured?
    redirect_to setup_path and return
  end

  def env_auth_configured?
    ENV["AUTH_USERNAME"].present? && ENV["AUTH_PASSWORD"].present?
  end

  # Test mode allows bypassing authentication for development and testing.
  # Enabled by setting TEST_MODE=true environment variable.
  # Never allowed in production for security.
  def test_mode_enabled?
    ENV["TEST_MODE"] == "true" && !Rails.env.production?
  end
end
