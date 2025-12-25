class CreateCategoryGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :category_groups do |t|
      t.string :name, null: false
      t.string :color, null: false
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end
  end
end
