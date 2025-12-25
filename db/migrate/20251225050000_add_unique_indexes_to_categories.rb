class AddUniqueIndexesToCategories < ActiveRecord::Migration[8.1]
  def change
    add_index :category_groups, :name, unique: true
    add_index :categories, [ :category_group_id, :name ], unique: true
  end
end
