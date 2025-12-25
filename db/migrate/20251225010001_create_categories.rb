class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.references :category_group, null: false, foreign_key: true
      t.integer :display_order, default: 0, null: false

      t.timestamps
    end

    add_index :categories, [ :category_group_id, :display_order ]
  end
end
