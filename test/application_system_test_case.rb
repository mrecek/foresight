# frozen_string_literal: true

require "test_helper"
require "capybara/rails"
require "selenium/webdriver"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

  Capybara.save_path = Rails.root.join("tmp/system-test-artifacts")
end
