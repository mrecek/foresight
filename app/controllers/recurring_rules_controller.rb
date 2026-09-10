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
    RecurringRuleCommand.create(@recurring_rule) { |rule| AuditLog.log_create(rule, request) }
    redirect_to recurring_rules_path, notice: "Recurring rule created with #{@recurring_rule.transactions.count} transactions generated."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    RecurringRuleCommand.update(@recurring_rule, recurring_rule_params) { |rule| AuditLog.log_update(rule, request) }
    redirect_to recurring_rules_path, notice: "Recurring rule updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    RecurringRuleCommand.destroy(@recurring_rule) { |rule| AuditLog.log_delete(rule, request) }
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
