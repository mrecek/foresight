# frozen_string_literal: true

require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_test_mode = ENV["TEST_MODE"]
    ENV["TEST_MODE"] = "true"
  end

  teardown { @original_test_mode.nil? ? ENV.delete("TEST_MODE") : ENV["TEST_MODE"] = @original_test_mode }

  test "settings page renders without writing" do
    assert_no_difference([ "Setting.count", "AuditLog.count" ]) do
      get edit_settings_path
    end
    assert_response :success
  end

  test "valid update changes the singleton and creates an audit event" do
    assert_difference("AuditLog.where(action: 'update').count", 1) do
      patch settings_path, params: { setting: { default_view_months: 6, session_timeout_minutes: 60 } }
    end

    assert_redirected_to root_path
    assert_equal 6, Setting.instance.default_view_months
    assert_equal 60, Setting.instance.session_timeout_minutes
  end

  test "invalid update renders errors without a mutation or audit event" do
    settings = Setting.instance
    original_timeout = settings.session_timeout_minutes

    assert_no_difference("AuditLog.count") do
      patch settings_path, params: { setting: { default_view_months: 2, session_timeout_minutes: 0 } }
    end

    assert_response :unprocessable_entity
    assert_equal original_timeout, settings.reload.session_timeout_minutes
  end
end
