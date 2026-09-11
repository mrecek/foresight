module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_setup
    before_action :require_authentication
    before_action :check_session_timeout
    before_action :update_last_seen
    helper_method :authenticated?, :test_mode_enabled?, :authentication_mode, :oidc_provider_name
  end

  private

  def authenticated?
    test_mode_enabled? || current_principal.present?
  end

  def require_authentication
    return if test_mode_enabled?

    unless current_principal
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
    principal = current_principal
    return unless principal

    if principal.expired?(
      idle_timeout_minutes: Setting.instance.session_timeout_minutes,
      absolute_timeout_minutes: authentication_configuration.absolute_session_lifetime_minutes
    )
      reset_session
      redirect_to login_path, flash: { info: "Your session has expired. Please log in again." }
      nil
    end
  end

  def session_expired?(last_seen_at, timeout_minutes)
    last_seen_at.to_time < timeout_minutes.minutes.ago
  end

  def update_last_seen
    return if test_mode_enabled?
    principal = current_principal
    return unless principal

    session[:principal] = principal.touch.to_session
  end

  def require_setup
    return if test_mode_enabled?
    return if authentication_configuration.setup_complete?(Setting.instance)

    redirect_to setup_path and return
  end

  def env_auth_configured?
    authentication_configuration.password_environment_credentials?
  end

  def authentication_configuration
    Foresight::Authentication::Configuration.new.validate!
  end

  def authentication_mode
    authentication_configuration.mode
  end

  def oidc_provider_name
    authentication_configuration.oidc_provider_name
  end

  def current_principal
    @current_principal ||= Foresight::Authentication::SessionPrincipal.from_session(session[:principal])
  end

  def establish_authenticated_session!(authentication_method:, subject:, issuer: nil)
    reset_session
    principal = Foresight::Authentication::SessionPrincipal.build(
      authentication_method: authentication_method,
      issuer: issuer,
      subject: subject
    )
    session[:principal] = principal.to_session
    @current_principal = principal
  end

  # Test mode allows bypassing authentication for development and testing.
  # Enabled by setting TEST_MODE=true environment variable.
  # Never allowed in production for security.
  def test_mode_enabled?
    ENV["TEST_MODE"] == "true" && !Rails.env.production?
  end
end
