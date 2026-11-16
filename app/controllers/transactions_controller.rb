class TransactionsController < ApplicationController
  include LoadableResources

  before_action :set_transaction, only: [ :edit, :update, :destroy, :confirm_actual, :mark_actual ]
  before_action :load_accounts, only: [ :index, :new, :create, :edit, :update ]
  before_action :load_categories, only: [ :new, :create, :edit, :update ]

  def index
    @settings = Setting.instance
    @selected_account_id = params[:account_id]

    @transactions = Transaction.upcoming
      .where(date: Date.current..(@settings.default_view_months.months.from_now))
      .for_account(@selected_account_id)
      .includes(:account, :recurring_rule, { category: :category_group }, { linked_transaction: :account })
      .order(:date)
  end

  def new
    @transaction = Transaction.new(date: Date.current, status: :actual, account_id: params[:account_id])
    @return_url = transaction_return_url
  end

  def create
    @transaction = TransferCommand.create(transaction_params) { |transaction| AuditLog.log_create(transaction, request) }
    redirect_to transaction_return_url, notice: "Transaction created."
  rescue ActiveRecord::RecordInvalid => error
    @transaction = error.record
    @return_url = transaction_return_url
    render :new, status: :unprocessable_entity
  end

  def edit
    @transaction = @transaction.linked_transaction if incoming_transfer?
    @return_url = transaction_return_url
  end

  def update
    if incoming_transfer?
      return redirect_to edit_transaction_path(@transaction.linked_transaction, return_url: transaction_return_url),
        alert: "Review this transfer from its sending account before saving."
    end

    TransactionChange.update(@transaction, attributes: transaction_params, audit_context: AuditContext.from_request(request))
    redirect_to transaction_return_url, notice: "Transaction updated."
  rescue ActiveRecord::RecordInvalid => error
    @transaction = error.record
    @return_url = transaction_return_url
    render :edit, status: :unprocessable_entity
  end

  def destroy
    TransferCommand.destroy(@transaction, exclude_occurrence: true) { |transaction| AuditLog.log_delete(transaction, request) }
    redirect_to transaction_return_url, notice: "Transaction deleted."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to transaction_return_url, alert: "Failed to delete transaction: #{e.message}"
  end

  def confirm_actual
    @return_url = transaction_return_url
  end

  def mark_actual
    TransactionChange.confirm_actual(@transaction, amount: params[:amount], audit_context: AuditContext.from_request(request))
    redirect_to transaction_return_url,
      notice: "Marked as actual with amount #{helpers.number_to_currency(@transaction.amount.abs)}."
  rescue ActiveRecord::RecordInvalid => e
    render_confirm_actual_error("Failed to update transaction: #{e.message}")
  end

  private

  def set_transaction
    @transaction = Transaction.includes(linked_transaction: :account).find(params[:id])
  end

  def incoming_transfer?
    @transaction.linked_transaction.present? && @transaction.amount.positive?
  end

  def transaction_params
    params.require(:transaction).permit(:account_id, :description, :amount, :date, :status, :category_id, :destination_account_id)
  end

  def transaction_return_url
    safe_return_url(fallback: transactions_path)
  end

  def render_confirm_actual_error(message)
    @return_url = transaction_return_url
    flash.now[:alert] = message
    render :confirm_actual, status: :unprocessable_entity
  end
end
