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
    if @account.save
      AuditLog.log_create(@account, request)
      redirect_to accounts_path, notice: "Account created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @account.update(account_params)
      AuditLog.log_update(@account, request)
      redirect_to accounts_path, notice: "Account updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    AuditLog.log_delete(@account, request)
    @account.destroy
    redirect_to accounts_path, notice: "Account deleted."
  end

  def reconcile
    if @account.update(reconcile_params)
      # Delete transactions before (or on, if include_today is set) the new balance date
      if params[:include_today] == "1"
        deleted_count = @account.transactions
          .where("date <= ?", @account.balance_date)
          .delete_all
      else
        deleted_count = @account.transactions
          .where("date < ?", @account.balance_date)
          .delete_all
      end

      AuditLog.log_update(@account, request)

      redirect_to root_path(account_id: @account.id),
        notice: "Reconciled! Removed #{deleted_count} old transaction#{'s' unless deleted_count == 1}."
    else
      redirect_to root_path(account_id: @account.id),
        alert: "Failed to reconcile: #{@account.errors.full_messages.join(', ')}"
    end
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
