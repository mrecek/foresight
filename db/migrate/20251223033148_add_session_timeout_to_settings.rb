class AddSessionTimeoutToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :session_timeout_minutes, :integer, default: 30, null: false
  end
end
