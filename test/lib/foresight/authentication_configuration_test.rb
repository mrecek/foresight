# frozen_string_literal: true

require "test_helper"
require "tempfile"

class Foresight::AuthenticationConfigurationTest < ActiveSupport::TestCase
  Configuration = Foresight::Authentication::Configuration

  test "password is the secure default mode" do
    configuration = build_configuration

    assert configuration.password?
    refute configuration.oidc?
    assert_equal 720, configuration.absolute_session_lifetime_minutes
    assert_same configuration, configuration.validate!
  end

  test "environment password credentials must be complete" do
    error = assert_raises(Configuration::Error) do
      build_configuration({ "AUTH_USERNAME" => "owner" }).validate!
    end

    assert_includes error.message, "AUTH_USERNAME and AUTH_PASSWORD must be configured together"
  end

  test "password and OIDC settings cannot be mixed" do
    error = assert_raises(Configuration::Error) do
      build_configuration({ "OIDC_ISSUER" => "https://identity.example.com" }).validate!
    end

    assert_includes error.message, "OIDC settings cannot be set when AUTH_MODE=password"
  end

  test "OIDC requires a complete configuration" do
    error = assert_raises(Configuration::Error) do
      build_configuration({ "AUTH_MODE" => "oidc" }).validate!
    end

    assert_includes error.message, "APP_URL is required"
    assert_includes error.message, "OIDC_ISSUER is required"
    assert_includes error.message, "OIDC_CLIENT_ID is required"
    assert_includes error.message, "OIDC_ALLOWED_SUBJECTS must contain at least one subject"
    assert_includes error.message, "configure exactly one of OIDC_CLIENT_SECRET or OIDC_CLIENT_SECRET_FILE"
  end

  test "complete OIDC configuration exposes exact callback and authorization values" do
    configuration = build_configuration(valid_oidc_environment).validate!

    assert configuration.oidc?
    assert_equal "https://identity.example.com/realms/foresight", configuration.oidc_issuer
    assert_equal "foresight", configuration.oidc_client_id
    assert_equal "client-secret", configuration.oidc_client_secret
    assert_equal [ "owner-subject", "backup-subject" ], configuration.oidc_allowed_subjects
    assert configuration.oidc_subject_allowed?("owner-subject")
    refute configuration.oidc_subject_allowed?("unknown")
    assert_equal "https://money.example.com/auth/openid_connect/callback", configuration.oidc_callback_url
  end

  test "OIDC accepts a readable secret file without retaining its newline" do
    Tempfile.create("foresight-oidc-secret") do |file|
      file.write("file-secret\n")
      file.flush
      environment = valid_oidc_environment.except("OIDC_CLIENT_SECRET").merge("OIDC_CLIENT_SECRET_FILE" => file.path)

      assert_equal "file-secret", build_configuration(environment).validate!.oidc_client_secret
    end
  end

  test "OIDC rejects dual secrets and unsafe public URLs" do
    error = assert_raises(Configuration::Error) do
      build_configuration(valid_oidc_environment.merge(
        "OIDC_CLIENT_SECRET_FILE" => __FILE__,
        "APP_URL" => "http://money.example.com/path"
      )).validate!
    end

    assert_includes error.message, "configure exactly one"
    assert_includes error.message, "APP_URL must be an absolute HTTPS URL without a path"
  end

  test "local HTTP callback URL is allowed outside production" do
    configuration = build_configuration(
      valid_oidc_environment.merge("APP_URL" => "http://127.0.0.1:3000"),
      rails_environment: "development"
    )

    assert_same configuration, configuration.validate!
  end

  test "absolute session lifetime is bounded" do
    assert_raises(Configuration::Error) do
      build_configuration({ "SESSION_ABSOLUTE_TIMEOUT_MINUTES" => "0" }).validate!
    end
    assert_raises(Configuration::Error) do
      build_configuration({ "SESSION_ABSOLUTE_TIMEOUT_MINUTES" => "1441" }).validate!
    end
    assert_raises(Configuration::Error) do
      build_configuration({ "SESSION_ABSOLUTE_TIMEOUT_MINUTES" => "forever" }).validate!
    end
  end

  private

  def build_configuration(environment = {}, rails_environment: "production")
    Configuration.new(environment: environment, rails_environment: rails_environment)
  end

  def valid_oidc_environment
    {
      "AUTH_MODE" => "oidc",
      "APP_URL" => "https://money.example.com/",
      "OIDC_ISSUER" => "https://identity.example.com/realms/foresight",
      "OIDC_CLIENT_ID" => "foresight",
      "OIDC_CLIENT_SECRET" => "client-secret",
      "OIDC_ALLOWED_SUBJECTS" => "owner-subject, backup-subject, owner-subject"
    }
  end
end
