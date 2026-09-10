# frozen_string_literal: true

require "test_helper"

class CategoryManagementControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_test_mode = ENV["TEST_MODE"]
    ENV["TEST_MODE"] = "true"
    @group = CategoryGroup.create!(name: "Living", color: "teal", display_order: 1)
  end

  teardown { @original_test_mode.nil? ? ENV.delete("TEST_MODE") : ENV["TEST_MODE"] = @original_test_mode }

  test "category management pages render" do
    category = @group.categories.create!(name: "Rent")
    get category_groups_path
    assert_response :success
    get new_category_group_path
    assert_response :success
    get edit_category_group_path(@group)
    assert_response :success
    get new_category_group_category_path(@group)
    assert_response :success
    get edit_category_group_category_path(@group, category)
    assert_response :success
  end

  test "category-group lifecycle is audited" do
    assert_difference([ "CategoryGroup.count", "AuditLog.where(action: 'create').count" ], 1) do
      post category_groups_path, params: { category_group: { name: "Food", color: "rose" } }
    end
    group = CategoryGroup.find_by!(name: "Food")
    assert_redirected_to category_groups_path

    assert_difference("AuditLog.where(action: 'update').count", 1) do
      patch category_group_path(group), params: { category_group: { name: "Meals", color: "orange" } }
    end
    assert_equal "Meals", group.reload.name

    assert_difference("AuditLog.where(action: 'delete').count", 1) do
      delete category_group_path(group)
    end
    refute CategoryGroup.exists?(group.id)
  end

  test "category lifecycle is audited and scoped to its group" do
    assert_difference([ "Category.count", "AuditLog.where(action: 'create').count" ], 1) do
      post category_group_categories_path(@group), params: { category: { name: "Utilities" } }
    end
    category = @group.categories.find_by!(name: "Utilities")

    assert_difference("AuditLog.where(action: 'update').count", 1) do
      patch category_group_category_path(@group, category), params: { category: { name: "Power" } }
    end
    assert_equal "Power", category.reload.name

    assert_difference("AuditLog.where(action: 'delete').count", 1) do
      delete category_group_category_path(@group, category)
    end
    refute Category.exists?(category.id)
  end

  test "validation errors do not create records or audit events" do
    assert_no_difference([ "CategoryGroup.count", "AuditLog.count" ]) do
      post category_groups_path, params: { category_group: { name: "", color: "unknown" } }
    end
    assert_response :unprocessable_entity

    assert_no_difference([ "Category.count", "AuditLog.count" ]) do
      post category_group_categories_path(@group), params: { category: { name: "" } }
    end
    assert_response :unprocessable_entity
  end
end
