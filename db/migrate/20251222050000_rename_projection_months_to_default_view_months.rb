class RenameProjectionMonthsToDefaultViewMonths < ActiveRecord::Migration[8.0]
  def change
    rename_column :settings, :projection_months, :default_view_months
  end
end
