class SetupController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :require_setup
  skip_before_action :check_session_timeout
  skip_before_action :update_last_seen
  before_action :redirect_if_setup_complete

  layout "auth"

  def new
    @settings = Setting.instance
  end

  def create
    @settings = Setting.instance
    @settings.auth_username = params[:username]
    @settings.auth_password = params[:password]

    if params[:password] != params[:password_confirmation]
      @settings.errors.add(:base, "Password confirmation doesn't match")
      render :new, status: :unprocessable_entity
      return
    end

    if @settings.save
      reset_session
      flash[:notice] = "Setup complete! Please log in."
      redirect_to login_path, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def redirect_if_setup_complete
    redirect_to root_path if Setting.instance.setup_complete? || env_auth_configured?
  end
end
