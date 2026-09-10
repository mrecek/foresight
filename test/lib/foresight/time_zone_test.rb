# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class ForesightTimeZoneTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "uses the existing Pacific default" do
    assert_equal "Pacific Time (US & Canada)", Foresight::TimeZone.resolve!(Foresight::TimeZone::DEFAULT)
  end

  test "accepts IANA and Rails timezone names" do
    assert_equal "America/New_York", Foresight::TimeZone.resolve!("America/New_York")
    assert_equal "Eastern Time (US & Canada)", Foresight::TimeZone.resolve!("Eastern Time (US & Canada)")
  end

  test "rejects invalid timezone names with actionable context" do
    error = assert_raises(ArgumentError) { Foresight::TimeZone.resolve!("Moon/Tranquility_Base") }

    assert_includes error.message, "APP_TIME_ZONE"
    assert_includes error.message, "Moon/Tranquility_Base"
  end

  test "invalid APP_TIME_ZONE fails application boot" do
    stdout, stderr, status = boot_application_with("Moon/Tranquility_Base")

    refute status.success?
    assert_empty stdout
    assert_includes stderr, "APP_TIME_ZONE"
    assert_includes stderr, "Moon/Tranquility_Base"
  end

  test "configured APP_TIME_ZONE becomes the Rails application zone" do
    stdout, stderr, status = boot_application_with("America/New_York")

    assert status.success?, stderr
    assert_equal "America/New_York", stdout.strip
  end

  test "Date.current follows the configured zone at a UTC date boundary" do
    travel_to Time.utc(2026, 1, 1, 7, 30) do
      Time.use_zone("America/Los_Angeles") { assert_equal Date.new(2025, 12, 31), Date.current }
      Time.use_zone("Asia/Tokyo") { assert_equal Date.new(2026, 1, 1), Date.current }
    end
  end

  test "zone arithmetic follows daylight-saving rules" do
    pacific = ActiveSupport::TimeZone["America/Los_Angeles"]
    arizona = ActiveSupport::TimeZone["America/Phoenix"]

    assert_equal "03:30 -0700", (pacific.local(2026, 3, 8, 1, 30) + 1.hour).strftime("%H:%M %z")
    assert_equal "02:30 -0700", (arizona.local(2026, 3, 8, 1, 30) + 1.hour).strftime("%H:%M %z")
  end

  test "recurring projection dates follow the local date in different zones" do
    rule = Struct.new(:anchor_date, :frequency).new(Date.new(2025, 12, 1), "daily")

    travel_to Time.utc(2026, 1, 1, 7, 30) do
      Time.use_zone("America/Los_Angeles") do
        assert_equal [ Date.new(2025, 12, 31), Date.new(2026, 1, 1) ],
          RecurrenceCalculator.new(rule).dates_until(Date.new(2026, 1, 1))
      end

      Time.use_zone("Asia/Tokyo") do
        assert_equal [ Date.new(2026, 1, 1) ],
          RecurrenceCalculator.new(rule).dates_until(Date.new(2026, 1, 1))
      end
    end
  end

  test "session timeout comparisons remain correct across zones and DST" do
    controller = ApplicationController.new

    travel_to Time.utc(2026, 3, 8, 10, 15) do
      [ "America/Los_Angeles", "America/New_York" ].each do |zone|
        Time.use_zone(zone) do
          assert controller.send(:session_expired?, 31.minutes.ago, 30)
          refute controller.send(:session_expired?, 29.minutes.ago, 30)
        end
      end
    end
  end

  private

  def boot_application_with(zone)
    Open3.capture3(
      { "APP_TIME_ZONE" => zone, "RAILS_ENV" => "test" },
      RbConfig.ruby,
      "-e",
      'require "./config/environment"; puts Rails.application.config.time_zone',
      chdir: Rails.root.to_s
    )
  end
end
