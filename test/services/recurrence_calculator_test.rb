require "test_helper"

class RecurrenceCalculatorTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(
      name: "Test Account",
      account_type: :checking,
      current_balance: 1000.0,
      balance_date: Date.current,
      warning_threshold: 0.0
    )
  end

  # Helper to create a recurring rule without triggering callbacks
  def create_rule(frequency:, anchor_date:, day_of_month: nil, day_of_week: nil)
    # Temporarily disable the callback for this creation
    RecurringRule.skip_callback(:create, :after, :generate_initial_transactions)

    rule = RecurringRule.create!(
      account: @account,
      description: "Test Rule",
      amount: 10.0, # Must be positive - sign applied based on rule_type
      frequency: frequency,
      anchor_date: anchor_date,
      day_of_month: day_of_month,
      day_of_week: day_of_week,
      rule_type: "expense"
    )

    # Re-enable the callback for future tests
    RecurringRule.set_callback(:create, :after, :generate_initial_transactions)

    rule
  rescue
    # Ensure callback is restored even if creation fails
    RecurringRule.set_callback(:create, :after, :generate_initial_transactions)
    raise
  end

  # ============================================================================
  # Daily Frequency Tests
  # ============================================================================

  test "daily frequency generates consecutive daily dates" do
    rule = create_rule(
      frequency: :daily,
      anchor_date: Date.new(2025, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 1, 5))

    assert_equal 5, dates.size
    assert_equal Date.new(2025, 1, 1), dates[0]
    assert_equal Date.new(2025, 1, 2), dates[1]
    assert_equal Date.new(2025, 1, 3), dates[2]
    assert_equal Date.new(2025, 1, 4), dates[3]
    assert_equal Date.new(2025, 1, 5), dates[4]
  end

  test "daily frequency starts from anchor date when start is before anchor" do
    rule = create_rule(
      frequency: :daily,
      anchor_date: Date.new(2025, 1, 10)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 5), Date.new(2025, 1, 12))

    assert_equal 3, dates.size
    assert_equal Date.new(2025, 1, 10), dates.first
    assert_equal Date.new(2025, 1, 12), dates.last
  end

  # ============================================================================
  # Weekly Frequency Tests
  # ============================================================================

  test "weekly frequency generates dates on same day of week from anchor" do
    rule = create_rule(
      frequency: :weekly,
      anchor_date: Date.new(2025, 1, 6) # Monday
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 1, 31))

    assert dates.all? { |d| d.wday == 1 }, "All dates should be Mondays"
    assert_equal [ Date.new(2025, 1, 6), Date.new(2025, 1, 13), Date.new(2025, 1, 20), Date.new(2025, 1, 27) ], dates
  end

  test "weekly frequency respects custom day_of_week" do
    rule = create_rule(
      frequency: :weekly,
      anchor_date: Date.new(2025, 1, 6), # Monday
      day_of_week: 5 # Friday
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 1, 31))

    assert dates.all? { |d| d.wday == 5 }, "All dates should be Fridays"
    assert_includes dates, Date.new(2025, 1, 3)
    assert_includes dates, Date.new(2025, 1, 10)
  end

  # ============================================================================
  # Biweekly Frequency Tests
  # ============================================================================

  test "biweekly frequency generates dates every 2 weeks from anchor" do
    rule = create_rule(
      frequency: :biweekly,
      anchor_date: Date.new(2025, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 3, 1))

    expected = [
      Date.new(2025, 1, 1),
      Date.new(2025, 1, 15),
      Date.new(2025, 1, 29),
      Date.new(2025, 2, 12),
      Date.new(2025, 2, 26)
    ]
    assert_equal expected, dates
  end

  test "biweekly frequency aligns to anchor date correctly when start is later" do
    rule = create_rule(
      frequency: :biweekly,
      anchor_date: Date.new(2025, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    # Start in February - should align to anchor's biweekly cycle
    dates = calculator.dates_between(Date.new(2025, 2, 1), Date.new(2025, 2, 28))

    # From Jan 1: +2w=Jan 15, +2w=Jan 29, +2w=Feb 12, +2w=Feb 26
    expected = [
      Date.new(2025, 2, 12),
      Date.new(2025, 2, 26)
    ]
    assert_equal expected, dates
  end

  # ============================================================================
  # Semimonthly Frequency Tests
  # ============================================================================

  test "semimonthly frequency generates 1st and 15th by default" do
    rule = create_rule(
      frequency: :semimonthly,
      anchor_date: Date.new(2025, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 2, 28))

    expected = [
      Date.new(2025, 1, 1),
      Date.new(2025, 1, 15),
      Date.new(2025, 2, 1),
      Date.new(2025, 2, 15)
    ]
    assert_equal expected, dates
  end

  test "semimonthly frequency respects custom day_of_month" do
    rule = create_rule(
      frequency: :semimonthly,
      anchor_date: Date.new(2025, 1, 1),
      day_of_month: 5
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 2, 28))

    expected = [
      Date.new(2025, 1, 5),
      Date.new(2025, 1, 15),
      Date.new(2025, 2, 5),
      Date.new(2025, 2, 15)
    ]
    assert_equal expected, dates
  end

  test "semimonthly frequency handles February correctly" do
    rule = create_rule(
      frequency: :semimonthly,
      anchor_date: Date.new(2025, 1, 1),
      day_of_month: 31
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 2, 1), Date.new(2025, 2, 28))

    # Feb 31 should become Feb 28 (safe_date handling)
    expected = [
      Date.new(2025, 2, 15),
      Date.new(2025, 2, 28) # Capped at last day of February
    ]
    assert_equal expected, dates
  end

  # ============================================================================
  # Monthly Frequency Tests
  # ============================================================================

  test "monthly frequency generates same day each month from anchor" do
    rule = create_rule(
      frequency: :monthly,
      anchor_date: Date.new(2025, 1, 15)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 4, 30))

    expected = [
      Date.new(2025, 1, 15),
      Date.new(2025, 2, 15),
      Date.new(2025, 3, 15),
      Date.new(2025, 4, 15)
    ]
    assert_equal expected, dates
  end

  test "monthly frequency respects custom day_of_month" do
    rule = create_rule(
      frequency: :monthly,
      anchor_date: Date.new(2025, 1, 1),
      day_of_month: 25
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 3, 31))

    expected = [
      Date.new(2025, 1, 25),
      Date.new(2025, 2, 25),
      Date.new(2025, 3, 25)
    ]
    assert_equal expected, dates
  end

  test "monthly frequency handles day overflow in shorter months" do
    rule = create_rule(
      frequency: :monthly,
      anchor_date: Date.new(2025, 1, 31)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 4, 30))

    # Jan 31 exists, Feb 31 → Feb 28, Mar 31 exists, Apr 31 → Apr 30
    expected = [
      Date.new(2025, 1, 31),
      Date.new(2025, 2, 28), # February only has 28 days in 2025
      Date.new(2025, 3, 31),
      Date.new(2025, 4, 30)  # April only has 30 days
    ]
    assert_equal expected, dates
  end

  test "monthly frequency handles leap year February correctly" do
    rule = create_rule(
      frequency: :monthly,
      anchor_date: Date.new(2024, 1, 31) # 2024 is a leap year
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2024, 1, 1), Date.new(2024, 3, 31))

    expected = [
      Date.new(2024, 1, 31),
      Date.new(2024, 2, 29), # Leap year - Feb has 29 days
      Date.new(2024, 3, 31)
    ]
    assert_equal expected, dates
  end

  # ============================================================================
  # Monthly Last Frequency Tests
  # ============================================================================

  test "monthly_last frequency generates last day of each month" do
    rule = create_rule(
      frequency: :monthly_last,
      anchor_date: Date.new(2025, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 4, 30))

    expected = [
      Date.new(2025, 1, 31),
      Date.new(2025, 2, 28), # Non-leap year
      Date.new(2025, 3, 31),
      Date.new(2025, 4, 30)
    ]
    assert_equal expected, dates
  end

  test "monthly_last frequency handles leap year February" do
    rule = create_rule(
      frequency: :monthly_last,
      anchor_date: Date.new(2024, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2024, 2, 1), Date.new(2024, 2, 29))

    expected = [ Date.new(2024, 2, 29) ] # Leap year February has 29 days
    assert_equal expected, dates
  end

  # ============================================================================
  # Quarterly Frequency Tests
  # ============================================================================

  test "quarterly frequency generates dates every 3 months from anchor" do
    rule = create_rule(
      frequency: :quarterly,
      anchor_date: Date.new(2025, 1, 15)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 12, 31))

    expected = [
      Date.new(2025, 1, 15),
      Date.new(2025, 4, 15),
      Date.new(2025, 7, 15),
      Date.new(2025, 10, 15)
    ]
    assert_equal expected, dates
  end

  test "quarterly frequency aligns to anchor when start is later" do
    rule = create_rule(
      frequency: :quarterly,
      anchor_date: Date.new(2025, 1, 15)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 5, 1), Date.new(2025, 12, 31))

    # From Jan 15: +3m=Apr 15, +3m=Jul 15, +3m=Oct 15
    expected = [
      Date.new(2025, 7, 15),
      Date.new(2025, 10, 15)
    ]
    assert_equal expected, dates
  end

  # ============================================================================
  # Biyearly Frequency Tests
  # ============================================================================

  test "biyearly frequency generates dates every 6 months from anchor" do
    rule = create_rule(
      frequency: :biyearly,
      anchor_date: Date.new(2025, 1, 15)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2025, 12, 31))

    expected = [
      Date.new(2025, 1, 15),
      Date.new(2025, 7, 15)
    ]
    assert_equal expected, dates
  end

  test "biyearly frequency aligns to anchor across multiple years" do
    rule = create_rule(
      frequency: :biyearly,
      anchor_date: Date.new(2024, 6, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2026, 12, 31))

    # From Jun 2024: +6m=Dec 2024, +6m=Jun 2025, +6m=Dec 2025, +6m=Jun 2026, +6m=Dec 2026
    expected = [
      Date.new(2025, 6, 1),
      Date.new(2025, 12, 1),
      Date.new(2026, 6, 1),
      Date.new(2026, 12, 1)
    ]
    assert_equal expected, dates
  end

  # ============================================================================
  # Yearly Frequency Tests
  # ============================================================================

  test "yearly frequency generates same date each year from anchor" do
    rule = create_rule(
      frequency: :yearly,
      anchor_date: Date.new(2025, 3, 15)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2028, 12, 31))

    expected = [
      Date.new(2025, 3, 15),
      Date.new(2026, 3, 15),
      Date.new(2027, 3, 15),
      Date.new(2028, 3, 15)
    ]
    assert_equal expected, dates
  end

  test "yearly frequency aligns to anchor when start is later" do
    rule = create_rule(
      frequency: :yearly,
      anchor_date: Date.new(2023, 6, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 1), Date.new(2027, 12, 31))

    # From Jun 2023: +1y=Jun 2024, +1y=Jun 2025, +1y=Jun 2026, +1y=Jun 2027
    expected = [
      Date.new(2025, 6, 1),
      Date.new(2026, 6, 1),
      Date.new(2027, 6, 1)
    ]
    assert_equal expected, dates
  end

  # ============================================================================
  # Edge Cases and Special Scenarios
  # ============================================================================

  test "dates_until uses current date as start when anchor is in the past" do
    rule = create_rule(
      frequency: :daily,
      anchor_date: Date.new(2020, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    # dates_until uses max of anchor_date and Date.current
    dates = calculator.dates_until(Date.current + 3.days)

    assert dates.first >= Date.current
    assert_equal 4, dates.size
  end

  test "dates_until uses anchor date when anchor is in the future" do
    future_date = Date.current + 10.days
    rule = create_rule(
      frequency: :daily,
      anchor_date: future_date
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_until(future_date + 3.days)

    assert_equal future_date, dates.first
    assert_equal 4, dates.size
  end

  test "empty date range returns empty array" do
    rule = create_rule(
      frequency: :daily,
      anchor_date: Date.new(2025, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 2, 1), Date.new(2025, 1, 31))

    assert_equal [], dates
  end

  test "single day range returns single date if it matches" do
    rule = create_rule(
      frequency: :daily,
      anchor_date: Date.new(2025, 1, 15)
    )
    calculator = RecurrenceCalculator.new(rule)

    dates = calculator.dates_between(Date.new(2025, 1, 15), Date.new(2025, 1, 15))

    assert_equal [ Date.new(2025, 1, 15) ], dates
  end

  test "safe_date helper caps day to last day of month" do
    rule = create_rule(
      frequency: :monthly,
      anchor_date: Date.new(2025, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    # Access private method for testing
    safe_date = calculator.send(:safe_date, 2025, 2, 31)

    assert_equal Date.new(2025, 2, 28), safe_date
  end

  test "safe_date helper handles leap year correctly" do
    rule = create_rule(
      frequency: :monthly,
      anchor_date: Date.new(2024, 1, 1)
    )
    calculator = RecurrenceCalculator.new(rule)

    safe_date = calculator.send(:safe_date, 2024, 2, 31)

    assert_equal Date.new(2024, 2, 29), safe_date # Leap year
  end

  test "all frequencies respect start and end date boundaries" do
    frequencies = [ :daily, :weekly, :biweekly, :semimonthly, :monthly, :monthly_last, :quarterly, :biyearly, :yearly ]

    frequencies.each do |freq|
      rule = create_rule(
        frequency: freq,
        anchor_date: Date.new(2025, 1, 1)
      )
      calculator = RecurrenceCalculator.new(rule)

      start_date = Date.new(2025, 3, 1)
      end_date = Date.new(2025, 6, 30)

      dates = calculator.dates_between(start_date, end_date)

      assert dates.all? { |d| d >= start_date && d <= end_date },
        "#{freq} frequency returned dates outside boundary: #{dates.inspect}"
    end
  end
end
