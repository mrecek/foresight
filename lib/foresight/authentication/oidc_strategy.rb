# frozen_string_literal: true

module Foresight
  module Authentication
    module OidcStrategy
      module_function

      def configure!(strategy, configuration)
        raise Configuration::Error, "OIDC sign-in is disabled" unless configuration.oidc?

        strategy.options.discovery = !configuration.oidc_explicit_endpoints?
        strategy.options.response_type = "code"
        strategy.options.scope = %i[openid profile email]
        strategy.options.send_state = true
        strategy.options.require_state = true
        strategy.options.send_nonce = true
        strategy.options.pkce = true
        strategy.options.client_auth_method = :basic
        strategy.options.issuer = configuration.oidc_issuer
        strategy.options.client_options.identifier = configuration.oidc_client_id
        strategy.options.client_options.secret = configuration.oidc_client_secret
        strategy.options.client_options.redirect_uri = configuration.oidc_callback_url
        configure_explicit_endpoints!(strategy, configuration) if configuration.oidc_explicit_endpoints?
        strategy
      end

      def configure_explicit_endpoints!(strategy, configuration)
        strategy.options.client_options.authorization_endpoint = configuration.oidc_authorization_endpoint
        strategy.options.client_options.token_endpoint = configuration.oidc_token_endpoint
        strategy.options.client_options.userinfo_endpoint = configuration.oidc_userinfo_endpoint
        strategy.options.client_options.jwks_uri = configuration.oidc_jwks_uri
      end
    end
  end
end
