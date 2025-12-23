# Ensure Settings exists
Setting.first_or_create!(default_view_months: 3)

unless ENV["SEED_DEMO_DATA"] == "true"
  puts "Skipping demo data (set SEED_DEMO_DATA=true to seed)"
  return
end

puts "Seeding demo data..."

# Clear existing data for demo seeding
Transaction.update_all(linked_transaction_id: nil)
Transaction.destroy_all
RecurringRule.destroy_all
Account.destroy_all

# Create accounts with balance_date set 2 weeks ago to show past transactions
checking = Account.create!(
  name: "Primary Checking",
  account_type: :checking,
  current_balance: 4000.00,
  balance_date: 14.days.ago.to_date
)

savings = Account.create!(
  name: "Savings Account",
  account_type: :savings,
  current_balance: 15000.00,
  balance_date: 14.days.ago.to_date
)

puts "Created #{Account.count} accounts"

# Helper to find next occurrence of a weekday (starting from 2 weeks ago for demo)
def next_weekday(wday, from_date = 14.days.ago.to_date)
  date = from_date
  date += 1.day until date.wday == wday
  date
end

# Create recurring rules (transactions will be auto-generated)

# Salary - biweekly on Fridays
RecurringRule.create!(
  account: checking,
  rule_type: :income,
  description: "Salary",
  amount: 3000.00,
  frequency: :biweekly,
  anchor_date: next_weekday(5), # Friday
  day_of_week: 5,
  is_estimated: true
)

# Rent - monthly on 1st
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Rent",
  amount: 1500.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 1,
  is_estimated: false # Fixed amount
)

# Savings Transfer - monthly on 15th (transfer to savings)
RecurringRule.create!(
  account: checking,
  destination_account: savings,
  rule_type: :transfer,
  description: "Savings Transfer",
  amount: 1000.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 15,
  is_estimated: false # Fixed amount
)

# Electric Bill - monthly on 24th
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Electric Bill",
  amount: 150.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 24,
  is_estimated: true
)

# Phone Bill - monthly on 9th
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Phone Bill",
  amount: 80.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 9,
  is_estimated: false # Fixed amount
)

# Car Insurance - biyearly (every 6 months) starting Jan 1
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Car Insurance",
  amount: 600.00,
  frequency: :biyearly,
  anchor_date: Date.new(Date.current.year, 1, 1),
  day_of_month: 1,
  is_estimated: true
)

# Credit Card Payment - monthly on 25th
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Credit Card Payment",
  amount: 100.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 25,
  is_estimated: true
)

# Credit Card Payment 2 - monthly on 3rd
RecurringRule.create!(
  account: checking,
  rule_type: :expense,
  description: "Credit Card Payment 2",
  amount: 200.00,
  frequency: :monthly,
  anchor_date: Date.current.beginning_of_month,
  day_of_month: 3,
  is_estimated: true
)

puts "Created #{RecurringRule.count} recurring rules"

# Create some one-time past transactions to demonstrate reconciliation
Transaction.create!(
  account: checking,
  description: "Coffee Shop",
  amount: -5.50,
  date: 5.days.ago.to_date,
  status: :actual
)

Transaction.create!(
  account: checking,
  description: "Gas Station",
  amount: -45.00,
  date: 3.days.ago.to_date,
  status: :actual
)

Transaction.create!(
  account: checking,
  description: "Grocery Store",
  amount: -127.35,
  date: 2.days.ago.to_date,
  status: :actual
)

Transaction.create!(
  account: checking,
  description: "Restaurant",
  amount: -38.50,
  date: 1.day.ago.to_date,
  status: :actual
)

# Transaction from today to test "include today" option
Transaction.create!(
  account: checking,
  description: "ATM Withdrawal",
  amount: -60.00,
  date: Date.current,
  status: :actual
)

puts "Generated #{Transaction.count} transactions (including #{Transaction.where('date < ?', Date.current).count} past and #{Transaction.where(date: Date.current).count} today)"
