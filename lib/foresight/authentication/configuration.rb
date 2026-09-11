# frozen_string_literal: true

require "uri"

module Foresight
  module Authentication
    class Configuration
      class Error < StandardError; end

      MODES = %w[password oidc].freeze
      OIDC_ENVIRONMENT_KEYS = %w[
        OIDC_ISSUER
        OIDC_CLIENT_ID
        OIDC_CLIENT_SECRET
        OIDC_CLIENT_SECRET_FILE
        OIDC_ALLOWED_SUBJECTS
        OIDC_PROVIDER_NAME
      ].freeze
      DEFAULT_ABSOLUTE_SESSION_LIFETIME_MINUTES = 720
      MAXIMUM_ABSOLUTE_SESSION_LIFETIME_MINUTES = 1440

      attr_reader :environment, :rails_environment

      def initialize(environment: ENV, rails_environment: Rails.env)
        @environment = environment
        @rails_environment = rails_environment.to_s
      end

      def validate!
        errors = []
        errors << "AUTH_MODE must be one of: #{MODES.join(', ')}" unless MODES.include?(mode)
        validate_password_configuration(errors)
        validate_oidc_configuration(errors)
        validate_absolute_session_lifetime(errors)

        raise Error, "Invalid authentication configuration: #{errors.join('; ')}" if errors.any?

        self
      end

      def mode
        environment.fetch("AUTH_MODE", "password").to_s.downcase
      end

      def password?
        mode == "password"
      end

      def oidc?
        mode == "oidc"
      end

      def setup_complete?(settings)
        oidc? || password_environment_credentials? || settings.setup_complete?
      end

      def password_environment_credentials?
        environment["AUTH_USERNAME"].present? && environment["AUTH_PASSWORD"].present?
      end

      def absolute_session_lifetime_minutes
        Integer(environment.fetch("SESSION_ABSOLUTE_TIMEOUT_MINUTES", DEFAULT_ABSOLUTE_SESSION_LIFETIME_MINUTES).to_s, 10)
      end

      def oidc_issuer
        environment["OIDC_ISSUER"].to_s
      end

      def oidc_client_id
        environment["OIDC_CLIENT_ID"].to_s
      end

      def oidc_client_secret
        return @oidc_client_secret if defined?(@oidc_client_secret)

        @oidc_client_secret = if environment["OIDC_CLIENT_SECRET"].present?
          environment["OIDC_CLIENT_SECRET"].to_s
        elsif environment["OIDC_CLIENT_SECRET_FILE"].present?
          File.read(environment["OIDC_CLIENT_SECRET_FILE"].to_s).strip
        end
      end

      def oidc_allowed_subjects
        environment["OIDC_ALLOWED_SUBJECTS"].to_s.split(",").map(&:strip).reject(&:empty?).uniq.freeze
      end

      def oidc_subject_allowed?(subject)
        oidc_allowed_subjects.include?(subject.to_s)
      end

      def oidc_provider_name
        environment["OIDC_PROVIDER_NAME"].presence || "OpenID Connect"
      end

      def public_url
        environment["APP_URL"].to_s.delete_suffix("/")
      end

      def oidc_callback_url
        "#{public_url}/auth/openid_connect/callback"
      end

      private

      def validate_password_configuration(errors)
        username_present = environment["AUTH_USERNAME"].present?
        password_present = environment["AUTH_PASSWORD"].present?
        if username_present != password_present
          errors << "AUTH_USERNAME and AUTH_PASSWORD must be configured together"
        end

        return unless oidc? && (username_present || password_present)

        errors << "AUTH_USERNAME and AUTH_PASSWORD cannot be set when AUTH_MODE=oidc"
      end

      def validate_oidc_configuration(errors)
        if password?
          configured_keys = OIDC_ENVIRONMENT_KEYS.select { |key| environment[key].present? }
          errors << "OIDC settings cannot be set when AUTH_MODE=password: #{configured_keys.join(', ')}" if configured_keys.any?
          return
        end
        return unless oidc?

        errors << "APP_URL is required when AUTH_MODE=oidc" if environment["APP_URL"].blank?
        errors << "OIDC_ISSUER is required when AUTH_MODE=oidc" if environment["OIDC_ISSUER"].blank?
        errors << "OIDC_CLIENT_ID is required when AUTH_MODE=oidc" if environment["OIDC_CLIENT_ID"].blank?
        errors << "OIDC_ALLOWED_SUBJECTS must contain at least one subject" if oidc_allowed_subjects.empty?

        direct_secret = environment["OIDC_CLIENT_SECRET"].present?
        secret_file = environment["OIDC_CLIENT_SECRET_FILE"].present?
        errors << "configure exactly one of OIDC_CLIENT_SECRET or OIDC_CLIENT_SECRET_FILE" unless direct_secret ^ secret_file

        validate_url(errors, "APP_URL", environment["APP_URL"], public: true) if environment["APP_URL"].present?
        validate_url(errors, "OIDC_ISSUER", environment["OIDC_ISSUER"]) if environment["OIDC_ISSUER"].present?
        validate_secret_file(errors) if secret_file
      end

      def validate_url(errors, name, value, public: false)
        uri = URI.parse(value.to_s)
        valid = uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil?
        valid &&= uri.path.blank? || uri.path == "/" if public
        valid &&= uri.scheme == "https" unless local_http_url_allowed?(uri)
        errors << "#{name} must be an absolute HTTPS URL#{' without a path' if public}" unless valid
      rescue URI::InvalidURIError
        errors << "#{name} must be an absolute HTTPS URL#{' without a path' if public}"
      end

      def local_http_url_allowed?(uri)
        rails_environment != "production" && uri.scheme == "http" && %w[localhost 127.0.0.1 ::1].include?(uri.host)
      end

      def validate_secret_file(errors)
        path = environment["OIDC_CLIENT_SECRET_FILE"].to_s
        unless File.file?(path) && File.readable?(path)
          errors << "OIDC_CLIENT_SECRET_FILE must name a readable regular file"
          return
        end

        errors << "OIDC_CLIENT_SECRET_FILE must not be empty" if File.read(path).strip.empty?
      rescue SystemCallError
        errors << "OIDC_CLIENT_SECRET_FILE could not be read"
      end

      def validate_absolute_session_lifetime(errors)
        lifetime = absolute_session_lifetime_minutes
        return if lifetime.between?(1, MAXIMUM_ABSOLUTE_SESSION_LIFETIME_MINUTES)

        errors << "SESSION_ABSOLUTE_TIMEOUT_MINUTES must be between 1 and #{MAXIMUM_ABSOLUTE_SESSION_LIFETIME_MINUTES}"
      rescue ArgumentError, TypeError
        errors << "SESSION_ABSOLUTE_TIMEOUT_MINUTES must be an integer"
      end
    end
  end
end
