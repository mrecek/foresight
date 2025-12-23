class AddWarningThresholdToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :warning_threshold, :decimal, precision: 12, scale: 2, null: false, default: 300
  end
end
