class DashboardController < ApplicationController
  def index
    @settings = Setting.instance
    @months_ahead = projection_months
    @end_date = @months_ahead.months.from_now.to_date

    # Every account card represents the selected dashboard range. Extend all
    # active projections before eager loading so each card has complete data.
    target_account = if params[:account_id].present?
      Account.find_by(id: params[:account_id])
    else
      Account.first
    end
    RecurringRule.extend_all_projections_to(@end_date)

    # Eager load transactions for all accounts (now includes extended projections)
    @accounts = Account.includes(:transactions)
    @account_projections = @accounts.index_with { |account| account.projection_summary(@end_date) }

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

  private

  def projection_months
    requested_months = params[:months].to_i
    return requested_months if [ 1, 3, 6, 9, 12, 24 ].include?(requested_months)

    @settings.default_view_months
  end
end
