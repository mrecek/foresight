class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :new, :create ]
  skip_before_action :check_session_timeout, only: [ :new, :create ]
  skip_before_action :update_last_seen, only: [ :new, :create ]
  layout "auth"

  def new
    redirect_to root_path if authenticated?
  end

  def create
    if valid_credentials?(params[:username], params[:password])
      session[:authenticated] = true
      session[:last_seen_at] = Time.current
      AuditLog.log_login_success(request)
      redirect_to root_path, notice: "Welcome back!"
    else
      AuditLog.log_login_failure(request, username: params[:username])
      flash.now[:alert] = "Invalid username or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "You have been logged out"
  end

  private

  def valid_credentials?(username, password)
    # Priority 1: Environment variables (for automated deployments)
    if ENV["AUTH_USERNAME"].present? && ENV["AUTH_PASSWORD"].present?
      return username == ENV["AUTH_USERNAME"] && password == ENV["AUTH_PASSWORD"]
    end

    # Priority 2: Database-stored credentials
    settings = Setting.instance
    return false unless settings.setup_complete?

    username == settings.auth_username && settings.authenticate_auth_password(password)
  end
end
