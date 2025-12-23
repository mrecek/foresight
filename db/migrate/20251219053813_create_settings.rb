class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.integer :projection_months, null: false, default: 6

      t.timestamps
    end
  end
end
