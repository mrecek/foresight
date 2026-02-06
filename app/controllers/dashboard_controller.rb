class DashboardController < ApplicationController
  def index
    @settings = Setting.instance
    @end_date_for_accounts = @settings.default_view_months.months.from_now.to_date

    # Default to settings default, expandable via param
    @months_ahead = (params[:months] || @settings.default_view_months).to_i
    @end_date = @months_ahead.months.from_now.to_date

    # Extend projections BEFORE eager loading accounts so the cached
    # transactions include any newly generated records
    target_account = if params[:account_id].present?
      Account.find_by(id: params[:account_id])
    else
      Account.first
    end
    RecurringRule.extend_all_projections_to(@end_date, account: target_account) if target_account

    # Eager load transactions for all accounts (now includes extended projections)
    @accounts = Account.includes(:transactions)

    # Select account from the eager-loaded collection
    @selected_account = if target_account
      @accounts.detect { |a| a.id == target_account.id } || @accounts.first
    else
      @accounts.first
    end

    return unless @selected_account

    # Get transactions from balance_date (last reconciliation) through end_date
    @transactions = @selected_account.transactions
      .where(date: @selected_account.balance_date..@end_date)
      .includes(:recurring_rule, { category: :category_group }, { linked_transaction: :account })
      .order(:date)

    # Calculate running balances
    @transactions_with_balances = @selected_account.running_balances_for(@transactions)

    # Group consecutive transactions from the same recurring rule (3+ items)
    @grouped_transactions = TransactionGrouper.new(@transactions_with_balances).call

    @attention_threshold = Date.current + 30.days
  end
end
