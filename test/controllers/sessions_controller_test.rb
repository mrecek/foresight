# frozen_string_literal: true

require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  def setup
    @original_environment = {
      "AUTH_USERNAME" => ENV["AUTH_USERNAME"],
      "AUTH_PASSWORD" => ENV["AUTH_PASSWORD"],
      "TEST_MODE" => ENV["TEST_MODE"]
    }
    ENV["AUTH_USERNAME"] = "configured-user"
    ENV["AUTH_PASSWORD"] = "configured-password"
    ENV.delete("TEST_MODE")
  end

  def teardown
    @original_environment.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "configured credentials authenticate and establish a session" do
    assert_difference("AuditLog.where(action: 'login_success').count", 1) do
      post login_path, params: { username: "configured-user", password: "configured-password" }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
  end

  test "either wrong configured credential is rejected" do
    [
      { username: "wrong-user", password: "configured-password" },
      { username: "configured-user", password: "wrong-password" },
      { username: "wrong-user", password: "wrong-password" }
    ].each do |credentials|
      assert_difference("AuditLog.where(action: 'login_failure').count", 1) do
        post login_path, params: credentials
      end

      assert_response :unprocessable_entity
      assert_select ".alert-danger", text: "Invalid username or password"
      failure = AuditLog.where(action: "login_failure").order(:id).last
      assert_nil failure.details
      refute_includes failure.attributes.to_json, credentials[:username]
      refute_includes failure.attributes.to_json, credentials[:password]
    end
  end

  test "missing configured credential parameters are rejected without error" do
    post login_path

    assert_response :unprocessable_entity
  end

  test "logout clears access to protected pages" do
    post login_path, params: { username: "configured-user", password: "configured-password" }
    assert_redirected_to root_path

    delete logout_path
    assert_redirected_to login_path

    get accounts_path
    assert_redirected_to login_path
  end

  test "an inactive session expires according to settings" do
    Setting.instance.update!(session_timeout_minutes: 30)
    post login_path, params: { username: "configured-user", password: "configured-password" }

    travel 31.minutes do
      get accounts_path
      assert_redirected_to login_path
      follow_redirect!
      assert_select ".alert-info", text: "Your session has expired. Please log in again."
    end
  end

  test "unauthenticated protected requests redirect with an explanation" do
    get accounts_path

    assert_redirected_to login_path
    follow_redirect!
    assert_select ".alert-info", text: "Please log in to continue"
  end
end

class SessionsControllerCredentialComparisonTest < ActiveSupport::TestCase
  test "username failure does not bypass password comparison" do
    controller = SessionsController.new
    comparisons = []
    controller.define_singleton_method(:secure_credential_match?) do |candidate, configured|
      comparisons << [ candidate, configured ]
      false
    end

    with_environment("AUTH_USERNAME" => "configured-user", "AUTH_PASSWORD" => "configured-password") do
      refute controller.send(:valid_credentials?, "wrong-user", "configured-password")
    end

    assert_equal [
      [ "wrong-user", "configured-user" ],
      [ "configured-password", "configured-password" ]
    ], comparisons
  end

  test "configured comparison hashes both values before secure comparison" do
    controller = SessionsController.new
    expected = OpenSSL::Digest::SHA256.hexdigest("same-value")
    security_utils_singleton = class << ActiveSupport::SecurityUtils
      self
    end
    original_secure_compare = security_utils_singleton.instance_method(:secure_compare)
    test_case = self

    security_utils_singleton.define_method(:secure_compare) do |left, right|
      test_case.assert_equal expected, left
      test_case.assert_equal expected, right
      true
    end

    assert controller.send(:secure_credential_match?, "same-value", "same-value")
  ensure
    security_utils_singleton&.define_method(:secure_compare, original_secure_compare) if original_secure_compare
  end

  private

  def with_environment(values)
    original = values.to_h { |key, _| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
