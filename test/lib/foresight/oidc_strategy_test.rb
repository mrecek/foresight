# frozen_string_literal: true

require "test_helper"

class Foresight::OidcStrategyTest < ActiveSupport::TestCase
  test "strategy requires the complete authorization-code security profile" do
    configuration = Foresight::Authentication::Configuration.new(
      environment: {
        "AUTH_MODE" => "oidc",
        "APP_URL" => "https://money.example.com",
        "OIDC_ISSUER" => "https://identity.example.com/realms/foresight",
        "OIDC_CLIENT_ID" => "foresight",
        "OIDC_CLIENT_SECRET" => "client-secret",
        "OIDC_ALLOWED_SUBJECTS" => "owner-subject"
      },
      rails_environment: "production"
    ).validate!
    strategy = OmniAuth::Strategies::OpenIDConnect.new(->(_environment) { [ 200, {}, [] ] })

    Foresight::Authentication::OidcStrategy.configure!(strategy, configuration)

    assert strategy.options.discovery
    assert_equal "code", strategy.options.response_type
    assert_equal %i[openid profile email], strategy.options.scope
    assert strategy.options.send_state
    assert strategy.options.require_state
    assert strategy.options.send_nonce
    assert strategy.options.pkce
    assert_equal "S256", strategy.options.pkce_options.code_challenge_method
    assert_respond_to strategy.options.pkce_options.code_challenge, :call
    assert_equal :basic, strategy.options.client_auth_method
    assert_equal "https://identity.example.com/realms/foresight", strategy.options.issuer
    assert_equal "foresight", strategy.options.client_options.identifier
    assert_equal "client-secret", strategy.options.client_options.secret
    assert_equal "https://money.example.com/auth/openid_connect/callback",
      strategy.options.client_options.redirect_uri
  end

  test "request initiation remains POST-only with Rails CSRF verification" do
    assert_equal [ :post ], OmniAuth.config.allowed_request_methods
    assert_instance_of OmniAuth::RailsCsrfProtection::TokenVerifier, OmniAuth.config.request_validation_phase
  end

  test "OIDC strategy cannot be activated in password mode" do
    configuration = Foresight::Authentication::Configuration.new(environment: {}, rails_environment: "test").validate!
    strategy = OmniAuth::Strategies::OpenIDConnect.new(->(_environment) { [ 200, {}, [] ] })

    error = assert_raises(Foresight::Authentication::Configuration::Error) do
      Foresight::Authentication::OidcStrategy.configure!(strategy, configuration)
    end

    assert_equal "OIDC sign-in is disabled", error.message
  end
end
