class AccountsController < ApplicationController
  before_action :set_account, only: [ :show, :edit, :update, :destroy, :reconcile ]

  def index
    @accounts = Account.all
  end

  def show
    @settings = Setting.instance
    @transactions = @account.transactions
      .where(date: @account.balance_date..(@settings.default_view_months.months.from_now))
      .order(:date)
  end

  def new
    @account = Account.new(balance_date: Date.current)
  end

  def create
    @account = Account.new(account_params)
    AuditedChange.create(@account, request)
    redirect_to accounts_path, notice: "Account created."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    AuditedChange.update(@account, account_params, request)
    redirect_to accounts_path, notice: "Account updated."
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    if AccountCommand.destroy(@account) { |account| AuditLog.log_delete(account, request) }
      redirect_to accounts_path, notice: "Account deleted."
    else
      redirect_to accounts_path, alert: @account.errors.full_messages.join(", ")
    end
  end

  def reconcile
    Account.transaction do
      @account.update!(reconcile_params)
      # Delete transactions before (or on, if include_today is set) the new balance date
      transactions_to_delete = if params[:include_today] == "1"
        @account.transactions.where("date <= ?", @account.balance_date)
      else
        @account.transactions.where("date < ?", @account.balance_date)
      end

      deleted_count = transactions_to_delete.count
      transactions_to_delete.ids.each do |transaction_id|
        transaction = Transaction.find_by(id: transaction_id)
        TransferCommand.destroy(transaction, pair: false) if transaction
      end

      AuditLog.log_update(@account, request)

      redirect_to root_path(account_id: @account.id),
        notice: "Reconciled! Removed #{deleted_count} old transaction#{'s' unless deleted_count == 1}."
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to root_path(account_id: @account.id),
      alert: "Failed to reconcile: #{@account.errors.full_messages.join(', ')}"
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.require(:account).permit(:name, :account_type, :current_balance, :balance_date, :warning_threshold)
  end

  def reconcile_params
    params.permit(:current_balance, :balance_date)
  end
end
