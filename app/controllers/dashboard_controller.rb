class DashboardController < ApplicationController
  def index
    @settings = Setting.instance
    @end_date_for_accounts = @settings.default_view_months.months.from_now.to_date

    # Eager load transactions within the projection period for all accounts
    # to avoid N+1 queries when displaying account status in the view
    @accounts = Account.includes(:transactions).references(:transactions)

    # Select account (default to first)
    @selected_account = if params[:account_id].present?
      Account.find_by(id: params[:account_id]) || @accounts.first
    else
      @accounts.first
    end

    return unless @selected_account

    # Default to settings default, expandable via param
    @months_ahead = (params[:months] || @settings.default_view_months).to_i
    @end_date = @months_ahead.months.from_now.to_date

    # Ensure projections exist up to the requested end_date (idempotent)
    RecurringRule.extend_all_projections_to(@end_date, account: @selected_account)

    # Get transactions from balance_date (last reconciliation) through end_date
    @transactions = @selected_account.transactions
      .where(date: @selected_account.balance_date..@end_date)
      .includes(:recurring_rule, { category: :category_group }, { linked_transaction: :account })
      .order(:date)

    # Calculate running balances
    @transactions_with_balances = @selected_account.running_balances_for(@transactions)

    @attention_threshold = Date.current + 30.days
  end
end
