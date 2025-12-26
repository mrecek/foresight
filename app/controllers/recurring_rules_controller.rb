class RecurringRulesController < ApplicationController
  include LoadableResources

  before_action :set_recurring_rule, only: [ :show, :edit, :update, :destroy ]
  before_action :load_accounts, only: [ :new, :create, :edit, :update ]
  before_action :load_categories, only: [ :new, :create, :edit, :update ]

  def index
    @recurring_rules = RecurringRule.includes(:account, :destination_account, category: :category_group).order(:description)
  end

  def show
    @upcoming = @recurring_rule.transactions.upcoming.limit(6)
  end

  def new
    @recurring_rule = RecurringRule.new(
      anchor_date: Date.current,
      is_estimated: true,
      active: true,
      rule_type: :expense,
      frequency: :monthly,
      day_of_month: 1
    )
  end

  def create
    @recurring_rule = RecurringRule.new(recurring_rule_params)
    if @recurring_rule.save
      AuditLog.log_create(@recurring_rule, request)
      redirect_to recurring_rules_path, notice: "Recurring rule created with #{@recurring_rule.transactions.count} transactions generated."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @recurring_rule.update(recurring_rule_params)
      AuditLog.log_update(@recurring_rule, request)
      redirect_to recurring_rules_path, notice: "Recurring rule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    AuditLog.log_delete(@recurring_rule, request)
    @recurring_rule.destroy
    redirect_to recurring_rules_path, notice: "Recurring rule and its transactions deleted."
  end

  private

  def set_recurring_rule
    @recurring_rule = RecurringRule.find(params[:id])
  end

  def recurring_rule_params
    params.require(:recurring_rule).permit(
      :account_id, :destination_account_id, :rule_type, :description,
      :amount, :frequency, :anchor_date, :day_of_month, :day_of_week,
      :is_estimated, :active, :category_id
    )
  end
end
