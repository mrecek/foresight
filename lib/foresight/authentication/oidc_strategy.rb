# frozen_string_literal: true

module Foresight
  module Authentication
    module OidcStrategy
      module_function

      def configure!(strategy, configuration)
        raise Configuration::Error, "OIDC sign-in is disabled" unless configuration.oidc?

        strategy.options.discovery = true
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
        strategy
      end
    end
  end
end
