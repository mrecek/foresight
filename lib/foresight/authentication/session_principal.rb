# frozen_string_literal: true

module Foresight
  module Authentication
    class SessionPrincipal
      METHODS = %w[password oidc].freeze
      VERSION = 1

      attr_reader :authentication_method, :issuer, :subject, :authenticated_at, :last_seen_at

      def self.build(authentication_method:, subject:, issuer: nil, now: Time.current)
        new(
          authentication_method: authentication_method,
          issuer: issuer,
          subject: subject,
          authenticated_at: now,
          last_seen_at: now
        )
      end

      def self.from_session(value)
        attributes = value.to_h.stringify_keys
        return unless attributes["version"] == VERSION

        new(
          authentication_method: attributes["method"],
          issuer: attributes["issuer"],
          subject: attributes["subject"],
          authenticated_at: Time.zone.at(Integer(attributes["authenticated_at"])),
          last_seen_at: Time.zone.at(Integer(attributes["last_seen_at"]))
        )
      rescue ArgumentError, NoMethodError, TypeError
        nil
      end

      def initialize(authentication_method:, subject:, authenticated_at:, last_seen_at:, issuer: nil)
        raise ArgumentError, "invalid authentication method" unless METHODS.include?(authentication_method)
        raise ArgumentError, "subject is required" if subject.blank?
        raise ArgumentError, "issuer is required for OIDC" if authentication_method == "oidc" && issuer.blank?
        raise ArgumentError, "issuer is not used for password sessions" if authentication_method == "password" && issuer.present?

        @authentication_method = authentication_method
        @issuer = issuer
        @subject = subject
        @authenticated_at = authenticated_at
        @last_seen_at = last_seen_at
        freeze
      end

      def expired?(idle_timeout_minutes:, absolute_timeout_minutes:, now: Time.current)
        last_seen_at < idle_timeout_minutes.minutes.ago(now) ||
          authenticated_at < absolute_timeout_minutes.minutes.ago(now)
      end

      def touch(now: Time.current)
        self.class.new(
          authentication_method: authentication_method,
          issuer: issuer,
          subject: subject,
          authenticated_at: authenticated_at,
          last_seen_at: now
        )
      end

      def to_session
        {
          "version" => VERSION,
          "method" => authentication_method,
          "issuer" => issuer,
          "subject" => subject,
          "authenticated_at" => authenticated_at.to_i,
          "last_seen_at" => last_seen_at.to_i
        }.compact
      end
    end
  end
end
