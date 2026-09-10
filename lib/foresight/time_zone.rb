# frozen_string_literal: true

module Foresight
  module TimeZone
    DEFAULT = "Pacific Time (US & Canada)"

    def self.resolve!(name)
      zone = ActiveSupport::TimeZone[name]
      return zone.name if zone

      raise ArgumentError,
        "APP_TIME_ZONE=#{name.inspect} is invalid. Use an IANA timezone such as America/New_York " \
        "or a Rails timezone such as Pacific Time (US & Canada)."
    end
  end
end
