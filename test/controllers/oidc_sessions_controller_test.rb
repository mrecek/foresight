# frozen_string_literal: true

require "test_helper"

class OidcSessionsControllerTest < ActionDispatch::IntegrationTest
  AUTH_ENVIRONMENT_KEYS = %w[
    AUTH_MODE AUTH_USERNAME AUTH_PASSWORD APP_URL OIDC_ISSUER OIDC_CLIENT_ID
    OIDC_CLIENT_SECRET OIDC_CLIENT_SECRET_FILE OIDC_ALLOWED_SUBJECTS OIDC_PROVIDER_NAME
    OIDC_AUTHORIZATION_ENDPOINT OIDC_TOKEN_ENDPOINT OIDC_USERINFO_ENDPOINT OIDC_JWKS_URI
    OIDC_ALLOW_INSECURE_BACKCHANNEL
    SESSION_ABSOLUTE_TIMEOUT_MINUTES TEST_MODE
  ].freeze

  setup do
    @original_environment = AUTH_ENVIRONMENT_KEYS.to_h { |key| [ key, ENV[key] ] }
    AUTH_ENVIRONMENT_KEYS.each { |key| ENV.delete(key) }
    ENV.update(
      "AUTH_MODE" => "oidc",
      "APP_URL" => "https://money.example.com",
      "OIDC_ISSUER" => "https://identity.example.com/realms/foresight",
      "OIDC_CLIENT_ID" => "foresight",
      "OIDC_CLIENT_SECRET" => "client-secret",
      "OIDC_ALLOWED_SUBJECTS" => "owner-subject,backup-subject",
      "OIDC_PROVIDER_NAME" => "Example Identity"
    )
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:openid_connect] = oidc_auth("owner-subject")
    Setting.instance.update_columns(auth_username: nil, auth_password_digest: nil)
  end

  teardown do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:openid_connect] = nil
    @original_environment.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  test "OIDC mode bypasses password setup and exposes only provider sign-in" do
    get setup_path
    assert_redirected_to root_path

    get login_path
    assert_response :success
    assert_select "form[action='/auth/openid_connect'][method='post'] button", text: "Continue with Example Identity"
    assert_select "input[name='username']", count: 0
    assert_select "input[name='password']", count: 0
  end

  test "password endpoint fails closed while OIDC mode is active" do
    assert_difference("AuditLog.where(action: 'login_failure').count", 1) do
      post login_path, params: { username: "owner", password: "password-123" }
    end

    assert_response :unprocessable_entity
    assert_select ".alert-danger", text: "Password sign-in is not available for this installation."
  end

  test "authorized callback establishes only a bounded issuer-subject principal" do
    assert_difference("AuditLog.where(action: 'login_success').count", 1) do
      get "/auth/openid_connect/callback"
    end

    assert_redirected_to root_path
    principal = Foresight::Authentication::SessionPrincipal.from_session(session[:principal])
    assert_equal "oidc", principal.authentication_method
    assert_equal "https://identity.example.com/realms/foresight", principal.issuer
    assert_equal "owner-subject", principal.subject
    refute_includes session.to_hash.to_json, "provider-access-token"
    refute_includes session.to_hash.to_json, "provider-refresh-token"
    refute_includes session.to_hash.to_json, "provider-id-token"
    refute_includes session.to_hash.to_json, "owner@example.com"

    event = AuditLog.where(action: "login_success").order(:id).last
    assert_includes event.details, "oidc"
    refute_includes event.details, "owner-subject"
    refute_includes event.details, "provider-access-token"
  end

  test "unlisted subject is denied and recorded without its raw identifier" do
    OmniAuth.config.mock_auth[:openid_connect] = oidc_auth("intruder-subject")

    assert_difference("AuditLog.where(action: 'login_denied').count", 1) do
      get "/auth/openid_connect/callback"
    end

    assert_redirected_to login_path
    assert_nil session[:principal]
    event = AuditLog.where(action: "login_denied").order(:id).last
    assert_includes event.details, "subject_not_allowed"
    refute_includes event.details, "intruder-subject"
  end

  test "each explicitly listed subject can establish the same shared-workspace session" do
    OmniAuth.config.mock_auth[:openid_connect] = oidc_auth("backup-subject")

    get "/auth/openid_connect/callback"

    assert_redirected_to root_path
    principal = Foresight::Authentication::SessionPrincipal.from_session(session[:principal])
    assert_equal "backup-subject", principal.subject
    assert_equal "https://identity.example.com/realms/foresight", principal.issuer
  end

  test "authorization is reevaluated for every new provider session" do
    get "/auth/openid_connect/callback"
    assert_redirected_to root_path
    delete logout_path

    ENV["OIDC_ALLOWED_SUBJECTS"] = "backup-subject"
    assert_difference("AuditLog.where(action: 'login_denied').count", 1) do
      get "/auth/openid_connect/callback"
    end

    assert_redirected_to login_path
    assert_nil session[:principal]
  end

  test "empty provider identity fails closed without storing claims" do
    OmniAuth.config.mock_auth[:openid_connect] = oidc_auth("")

    assert_difference("AuditLog.where(action: 'login_failure').count", 1) do
      get "/auth/openid_connect/callback"
    end

    assert_redirected_to login_path
    assert_nil session[:principal]
    event = AuditLog.where(action: "login_failure").order(:id).last
    refute_includes event.attributes.to_json, "provider-access-token"
    refute_includes event.attributes.to_json, "owner@example.com"
  end

  test "provider failure is generic and leaves no authenticated session" do
    OmniAuth.config.mock_auth[:openid_connect] = :invalid_credentials

    assert_difference("AuditLog.where(action: 'login_failure').count", 1) do
      get "/auth/openid_connect/callback"
      follow_redirect!
    end

    assert_redirected_to login_path
    follow_redirect!
    assert_select ".alert-danger", text: "Single sign-on could not be completed. Please try again."
    assert_nil session[:principal]
  end

  test "logout is local and access requires a fresh provider callback" do
    get "/auth/openid_connect/callback"
    assert_redirected_to root_path

    delete logout_path
    assert_redirected_to login_path
    get accounts_path
    assert_redirected_to login_path
  end

  private

  def oidc_auth(subject)
    OmniAuth::AuthHash.new(
      provider: "openid_connect",
      uid: subject,
      info: { email: "owner@example.com", name: "Owner" },
      credentials: {
        token: "provider-access-token",
        refresh_token: "provider-refresh-token",
        id_token: "provider-id-token"
      },
      extra: { raw_info: { sub: subject } }
    )
  end
end
