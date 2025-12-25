# Ensure Settings exists
Setting.first_or_create!(default_view_months: 3)

unless ENV["SEED_DEMO_DATA"] == "true"
  puts "Skipping demo data (set SEED_DEMO_DATA=true to seed)"
  return
end

puts "Seeding demo data..."

# Set up demo credentials for easy testing (demo / demo1234)
settings = Setting.instance
unless settings.setup_complete?
  settings.update!(
    auth_username: "demo",
    auth_password: "demo1234"
  )
  puts "Created demo credentials (username: demo, password: demo1234)"
end

# Clear existing data for demo seeding
Transaction.update_all(linked_transaction_id: nil)
Transaction.destroy_all
RecurringRule.destroy_all
Category.destroy_all
CategoryGroup.destroy_all
Account.destroy_all

# Create accounts with balance_date set 2 weeks ago to show past transactions
checking = Account.create!(
  name: "Primary Checking",
  account_type: :checking,
  current_balance: 5200.00,
  balance_date: 14.days.ago.to_date
)

savings = Account.create!(
  name: "Savings Account",
  account_type: :savings,
  current_balance: 18500.00,
  balance_date: 14.days.ago.to_date
)

puts "Created #{Account.count} accounts"

# ============================================================================
# CATEGORY GROUPS & CATEGORIES
# ============================================================================

# Income category group
income_group = CategoryGroup.create!(name: "Income", color: "teal", display_order: 1)
cat_salary = income_group.categories.create!(name: "Salary", display_order: 1)

# Housing category group
housing_group = CategoryGroup.create!(name: "Housing", color: "purple", display_order: 2)
cat_rent = housing_group.categories.create!(name: "Rent/Mortgage", display_order: 1)

# Bills & Utilities category group
bills_group = CategoryGroup.create!(name: "Bills & Utilities", color: "sky", display_order: 3)
cat_utilities = bills_group.categories.create!(name: "Utilities", display_order: 1)
cat_internet = bills_group.categories.create!(name: "Internet", display_order: 2)
cat_mobile_phone = bills_group.categories.create!(name: "Mobile Phone", display_order: 3)

# Transportation category group
transport_group = CategoryGroup.create!(name: "Transportation", color: "orange", display_order: 4)
cat_auto_insurance = transport_group.categories.create!(name: "Auto Insurance", display_order: 1)


# Insurance category group
insurance_group = CategoryGroup.create!(name: "Insurance", color: "rose", display_order: 5)
cat_health_insurance = insurance_group.categories.create!(name: "Health Insurance", display_order: 1)

# Financial category group
financial_group = CategoryGroup.create!(name: "Financial", color: "fuchsia", display_order: 6)
cat_credit_cards = financial_group.categories.create!(name: "Credit Cards", display_order: 1)
cat_savings = financial_group.categories.create!(name: "Savings", display_order: 2)

# Lifestyle category group
lifestyle_group = CategoryGroup.create!(name: "Lifestyle", color: "lime", display_order: 7)
cat_subscriptions = lifestyle_group.categories.create!(name: "Subscriptions", display_order: 1)
cat_dining = lifestyle_group.categories.create!(name: "Dining", display_order: 2)
cat_shopping = lifestyle_group.categories.create!(name: "Shopping", display_order: 3)

puts "Created #{CategoryGroup.count} category groups with #{Category.count} categories"

# ============================================================================
# HELPER METHODS
# ============================================================================

# Helper to find next occurrence of a weekday (starting from 2 weeks ago for demo)
def next_weekday(wday, from_date = 14.days.ago.to_date)
  date = from_date
  date += 1.day until date.wday == wday
  date
end

# ============================================================================
# RECURRING RULES - Income
# ============================================================================

# Salary - biweekly on Fridays (KNOWN amount - not estimated)
RecurringRule.create!(
  account: checking,
  rule_type: :income,
  description: "Work Salary",
  amount: 3000.00,
  frequency: :biweekly,
  anchor_date: next_weekday(5), # Friday
  day_of_week: 5,
  is_estimated: false, # Salary is a known, fixed amount
  category: cat_salary
)

# ============================================================================
# RECURRING RULES - Housing
# ============================================================================

# Rent - monthly on 1st (fixed lease amount)
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Rent",
  amount: 1650.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 1,
  is_estimated: false,
  category: cat_rent
)

# Electric/Gas - monthly on 24th (variable by usage)
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Xcel Energy",
  amount: 145.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 24,
  is_estimated: true, # Varies by usage
  category: cat_utilities
)

# Internet - monthly on 12th (fixed plan)
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Comcast Internet",
  amount: 79.99,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 12,
  is_estimated: false, # Fixed monthly plan
  category: cat_internet
)

# Mobile Phone - monthly on 18th (fixed plan)
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Verizon Wireless",
  amount: 85.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 18,
  is_estimated: false,
  category: cat_mobile_phone
)

# ============================================================================
# RECURRING RULES - Insurance (typically ACH for discounts)
# ============================================================================

# Auto Insurance - biyearly (every 6 months) - quoted premium
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "State Farm Auto",
  amount: 580.00,
  frequency: :biyearly,
  anchor_date: Date.new(Date.current.year, 1, 15),
  day_of_month: 15,
  is_estimated: false, # Quoted premium for 6-month policy
  category: cat_auto_insurance
)

# Health Insurance - monthly on 1st (fixed premium)
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Blue Cross Health",
  amount: 425.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 1,
  is_estimated: false, # Fixed monthly premium
  category: cat_health_insurance
)

# ============================================================================
# RECURRING RULES - Financial
# ============================================================================

# Chase credit card - monthly on 25th (variable spending)
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Chase Sapphire",
  amount: 450.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 25,
  is_estimated: true, # Statement balance varies with spending
  category: cat_credit_cards
)

# Amex credit card - monthly on 15th (variable spending)
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Amex Blue Cash",
  amount: 275.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 15,
  is_estimated: true, # Statement balance varies with spending
  category: cat_credit_cards
)

# Savings Transfer - monthly on 20th (fixed auto-transfer)
RecurringRule.create!(
  account: checking,
  destination_account: savings,
  rule_type: :transfer,
  description: "Monthly Savings",
  amount: 750.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 20,
  is_estimated: false, # Fixed transfer amount
  category: cat_savings
)

# ============================================================================
# RECURRING RULES - Lifestyle (often ACH-only or offer discounts)
# ============================================================================

# Gym membership - monthly on 5th (ACH required)
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Planet Fitness",
  amount: 24.99,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 5,
  is_estimated: false, # Fixed membership fee
  category: cat_subscriptions
)

puts "Created #{RecurringRule.count} recurring rules"

# ============================================================================
# ONE-TIME TRANSACTIONS (past transactions to demonstrate reconciliation)
# ============================================================================

# Transactions from the past week - these would typically be debit card purchases
# or checks that hit the checking account directly


Transaction.create!(
  account: checking,
  description: "Target - Household",
  amount: -87.32,
  date: 4.days.ago.to_date,
  status: :actual,
  category: cat_shopping
)

Transaction.create!(
  account: checking,
  description: "Venmo - Split dinner",
  amount: -28.50,
  date: 3.days.ago.to_date,
  status: :actual,
  category: cat_dining
)

Transaction.create!(
  account: checking,
  description: "ATM Withdrawal",
  amount: -60.00,
  date: 2.days.ago.to_date,
  status: :actual
)


# Transaction from today to test "include today" option
Transaction.create!(
  account: checking,
  description: "Starbucks",
  amount: -7.25,
  date: Date.current,
  status: :actual,
  category: cat_dining
)

puts "Generated #{Transaction.count} transactions (including #{Transaction.where('date < ?', Date.current).count} past and #{Transaction.where(date: Date.current).count} today)"
