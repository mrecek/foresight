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
    if @category_group.save
      AuditLog.log_create(@category_group, request)
      redirect_to category_groups_path, notice: "Category group created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category_group.update(category_group_params)
      AuditLog.log_update(@category_group, request)
      redirect_to category_groups_path, notice: "Category group updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    AuditLog.log_delete(@category_group, request)
    @category_group.destroy
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
