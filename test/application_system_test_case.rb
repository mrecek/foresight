# frozen_string_literal: true

require "test_helper"
require "capybara/rails"
require "selenium/webdriver"

# Use Capybara's generic reset. Its Chrome specialization sends a wildcard
# origin to clear storage, which current Chrome rejects.
require "capybara/selenium/driver"
Capybara::Selenium::Driver.specializations.delete(:chrome)

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]

  Capybara.save_path = Rails.root.join("tmp/system-test-artifacts")
end
