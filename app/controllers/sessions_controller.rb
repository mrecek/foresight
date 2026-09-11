class SessionsController < ApplicationController
  PUBLIC_ACTIONS = %i[new create oidc_callback failure].freeze

  skip_before_action :require_authentication, only: PUBLIC_ACTIONS
  skip_before_action :check_session_timeout, only: PUBLIC_ACTIONS
  skip_before_action :update_last_seen, only: PUBLIC_ACTIONS
  layout "auth"

  def new
    redirect_to root_path if authenticated?
  end

  def create
    unless authentication_configuration.password?
      AuditLog.log_login_failure(request, method: "oidc", reason: "password_login_disabled")
      flash.now[:alert] = "Password sign-in is not available for this installation."
      render :new, status: :unprocessable_entity
      return
    end

    if valid_credentials?(params[:username], params[:password])
      subject = password_subject
      establish_authenticated_session!(authentication_method: "password", subject: subject)
      AuditLog.log_login_success(request, method: "password", subject: subject)
      redirect_to root_path
    else
      AuditLog.log_login_failure(request)
      flash.now[:alert] = "Invalid username or password"
      render :new, status: :unprocessable_entity
    end
  end

  def oidc_callback
    configuration = authentication_configuration
    auth = request.env["omniauth.auth"]
    subject = auth&.uid.to_s

    unless configuration.oidc? && auth&.provider == "openid_connect" && subject.present?
      AuditLog.log_login_failure(request, method: "oidc", reason: "invalid_callback", issuer: configuration.oidc_issuer)
      redirect_to login_path, alert: "Single sign-on could not be completed. Please try again."
      return
    end

    unless configuration.oidc_subject_allowed?(subject)
      reset_session
      AuditLog.log_login_denied(request, issuer: configuration.oidc_issuer, subject: subject)
      redirect_to login_path, alert: "This identity is not authorized to access Foresight."
      return
    end

    establish_authenticated_session!(
      authentication_method: "oidc",
      issuer: configuration.oidc_issuer,
      subject: subject
    )
    AuditLog.log_login_success(
      request,
      method: "oidc",
      issuer: configuration.oidc_issuer,
      subject: subject
    )
    redirect_to root_path
  end

  def failure
    configuration = authentication_configuration
    AuditLog.log_login_failure(
      request,
      method: "oidc",
      reason: "provider_failure",
      issuer: configuration.oidc? ? configuration.oidc_issuer : nil
    )
    redirect_to login_path, alert: "Single sign-on could not be completed. Please try again."
  end

  def destroy
    reset_session
    redirect_to login_path, flash: { info: "You've been signed out." }
  end

  private

  def valid_credentials?(username, password)
    return false unless authentication_configuration.password?

    # Priority 1: Environment variables (for automated deployments)
    if ENV["AUTH_USERNAME"].present? && ENV["AUTH_PASSWORD"].present?
      username_matches = secure_credential_match?(username, ENV["AUTH_USERNAME"])
      password_matches = secure_credential_match?(password, ENV["AUTH_PASSWORD"])

      # Evaluate both comparisons for every configured-credential attempt.
      return username_matches & password_matches
    end

    # Priority 2: Database-stored credentials
    settings = Setting.instance
    return false unless settings.setup_complete?

    username == settings.auth_username && settings.authenticate_auth_password(password)
  end

  def password_subject
    ENV["AUTH_USERNAME"].presence || Setting.instance.auth_username
  end

  def secure_credential_match?(candidate, configured_value)
    candidate_digest = OpenSSL::Digest::SHA256.hexdigest(candidate.to_s)
    configured_digest = OpenSSL::Digest::SHA256.hexdigest(configured_value.to_s)

    ActiveSupport::SecurityUtils.secure_compare(candidate_digest, configured_digest)
  end
end
