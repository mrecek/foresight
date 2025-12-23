class RecurringRulesController < ApplicationController
  before_action :set_recurring_rule, only: [ :show, :edit, :update, :destroy ]

  def index
    @recurring_rules = RecurringRule.includes(:account, :destination_account).order(:description)
  end

  def show
    @upcoming = @recurring_rule.transactions.upcoming.limit(6)
  end

  def new
    @recurring_rule = RecurringRule.new(
      anchor_date: Date.current,
      is_estimated: true,
      active: true
    )
    @accounts = Account.all
  end

  def create
    @recurring_rule = RecurringRule.new(recurring_rule_params)
    if @recurring_rule.save
      AuditLog.log_create(@recurring_rule, request)
      redirect_to recurring_rules_path, notice: "Recurring rule created with #{@recurring_rule.transactions.count} transactions generated."
    else
      @accounts = Account.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @accounts = Account.all
  end

  def update
    if @recurring_rule.update(recurring_rule_params)
      AuditLog.log_update(@recurring_rule, request)
      redirect_to recurring_rules_path, notice: "Recurring rule updated."
    else
      @accounts = Account.all
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
      :is_estimated, :active
    )
  end
end
