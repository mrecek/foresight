class AddCategoryToRecurringRules < ActiveRecord::Migration[8.1]
  def change
    add_reference :recurring_rules, :category, foreign_key: true
  end
end
