class CategoryGroupsController < ApplicationController
  before_action :set_category_group, only: [ :edit, :update, :destroy ]

  def index
    @category_groups = CategoryGroup.ordered.includes(:categories)
  end

  def new
    @category_group = CategoryGroup.new
  end

  def create
    @category_group = CategoryGroup.new(category_group_params)
    AuditedChange.create(@category_group, request)
    redirect_to category_groups_path, notice: "Category group created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    AuditedChange.update(@category_group, category_group_params, request)
    redirect_to category_groups_path, notice: "Category group updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    AuditedChange.destroy(@category_group, request)
    redirect_to category_groups_path, notice: "Category group deleted."
  end

  private

  def set_category_group
    @category_group = CategoryGroup.find(params[:id])
  end

  def category_group_params
    params.require(:category_group).permit(:name, :color)
  end
end
