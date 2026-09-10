class CategoriesController < ApplicationController
  before_action :set_category_group
  before_action :set_category, only: [ :edit, :update, :destroy ]

  def new
    @category = @category_group.categories.build
  end

  def create
    @category = @category_group.categories.build(category_params)
    AuditedChange.create(@category, request)
    redirect_to category_groups_path, notice: "Category created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    AuditedChange.update(@category, category_params, request)
    redirect_to category_groups_path, notice: "Category updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    AuditedChange.destroy(@category, request)
    redirect_to category_groups_path, notice: "Category deleted."
  end

  private

  def set_category_group
    @category_group = CategoryGroup.find(params[:category_group_id])
  end

  def set_category
    @category = @category_group.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name)
  end
end
