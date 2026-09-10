class SettingsController < ApplicationController
  def edit
    @settings = Setting.instance
  end

  def update
    @settings = Setting.instance
    AuditedChange.update(@settings, settings_params, request)
    redirect_to root_path, notice: "Settings updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  private

  def settings_params
    params.require(:setting).permit(:default_view_months, :session_timeout_minutes)
  end
end
