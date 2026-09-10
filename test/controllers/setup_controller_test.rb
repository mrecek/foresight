# frozen_string_literal: true

require "test_helper"

class SetupControllerTest < ActionDispatch::IntegrationTest
  setup do
    @environment = %w[AUTH_USERNAME AUTH_PASSWORD TEST_MODE].to_h { |key| [ key, ENV[key] ] }
    @environment.each_key { |key| ENV.delete(key) }
    Setting.instance.update_columns(auth_username: nil, auth_password_digest: nil)
  end

  teardown do
    @environment.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "first run redirects protected requests to setup" do
    get accounts_path

    assert_redirected_to setup_path
  end

  test "setup renders and rejects mismatched or short passwords" do
    get setup_path
    assert_response :success

    post setup_path, params: { username: "owner", password: "long-enough", password_confirmation: "different" }
    assert_response :unprocessable_entity
    refute Setting.instance.setup_complete?

    post setup_path, params: { username: "owner", password: "short", password_confirmation: "short" }
    assert_response :unprocessable_entity
    refute Setting.instance.setup_complete?
  end

  test "valid setup stores a password digest and sends the owner to login" do
    post setup_path, params: {
      username: "owner",
      password: "correct horse battery staple",
      password_confirmation: "correct horse battery staple"
    }

    assert_redirected_to login_path
    settings = Setting.instance
    assert settings.setup_complete?
    assert settings.authenticate_auth_password("correct horse battery staple")
    refute_equal "correct horse battery staple", settings.auth_password_digest
  end

  test "completed database or environment setup cannot be repeated" do
    settings = Setting.instance
    settings.update!(auth_username: "owner", auth_password: "password-123")
    get setup_path
    assert_redirected_to root_path

    settings.update_columns(auth_username: nil, auth_password_digest: nil)
    ENV["AUTH_USERNAME"] = "environment-owner"
    ENV["AUTH_PASSWORD"] = "environment-password"
    get setup_path
    assert_redirected_to root_path
  end
end
