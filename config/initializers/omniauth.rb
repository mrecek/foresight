# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :openid_connect,
    name: "openid_connect",
    setup: lambda { |environment|
      configuration = Foresight::Authentication::Configuration.new.validate!
      Foresight::Authentication::OidcStrategy.configure!(environment.fetch("omniauth.strategy"), configuration)
    }
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true

Rails.application.config.after_initialize do
  Foresight::Authentication::Configuration.new.validate!
end
