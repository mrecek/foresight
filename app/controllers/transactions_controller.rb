class TransactionsController < ApplicationController
  before_action :set_transaction, only: [ :show, :edit, :update, :destroy, :confirm_actual, :mark_actual ]

  def index
    @settings = Setting.instance
    @accounts = Account.all
    @selected_account_id = params[:account_id]

    @transactions = Transaction.upcoming
      .where(date: Date.current..(@settings.default_view_months.months.from_now))
      .for_account(@selected_account_id)
      .includes(:account, :recurring_rule)
      .order(:date)
  end

  def show
  end

  def new
    @transaction = Transaction.new(date: Date.current, status: :actual, account_id: params[:account_id])
    @accounts = Account.all
  end

  def create
    @transaction = Transaction.new(transaction_params)
    if @transaction.save
      AuditLog.log_create(@transaction, request)
      redirect_to transactions_path, notice: "Transaction created."
    else
      @accounts = Account.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @accounts = Account.all
  end

  def update
    if @transaction.update(transaction_params)
      AuditLog.log_update(@transaction, request)
      redirect_to transactions_path, notice: "Transaction updated."
    else
      @accounts = Account.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    linked = @transaction.linked_transaction
    AuditLog.log_delete(@transaction, request)
    ActiveRecord::Base.transaction do
      @transaction.destroy!
      linked&.destroy!
    end
    redirect_to transactions_path, notice: "Transaction deleted."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to transactions_path, alert: "Failed to delete transaction: #{e.message}"
  end

  def confirm_actual
  end

  def mark_actual
    # Validate required parameters
    unless params[:amount].present? && params[:original_sign].present?
      return redirect_back fallback_location: transactions_path, alert: "Missing required parameters."
    end

    # User enters positive amount, original_sign preserves the transaction type
    entered_amount = params[:amount].to_d.abs
    sign = params[:original_sign].to_i

    unless sign == 1 || sign == -1
      return redirect_back fallback_location: transactions_path, alert: "Invalid sign parameter."
    end

    new_amount = entered_amount * sign

    ActiveRecord::Base.transaction do
      @transaction.update!(status: :actual, amount: new_amount)

      # Update linked transaction for transfers (with opposite sign)
      if linked = @transaction.linked_transaction
        linked_amount = -new_amount
        linked.update!(status: :actual, amount: linked_amount)
      end
    end

    redirect_back fallback_location: transactions_path, notice: "Marked as actual with amount #{helpers.number_to_currency(entered_amount)}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: transactions_path, alert: "Failed to update transaction: #{e.message}"
  end

  private

  def set_transaction
    @transaction = Transaction.find(params[:id])
  end

  def transaction_params
    params.require(:transaction).permit(:account_id, :description, :amount, :date, :status)
  end
end
