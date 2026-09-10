ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Disabled parallelization to avoid database conflicts
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # Use transactional tests to rollback database changes after each test
    self.use_transactional_tests = true

    def create_recurring_rule!(**attributes)
      RecurringRuleCommand.create(RecurringRule.new(attributes))
    end
  end
end
