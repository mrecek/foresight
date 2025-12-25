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
  end

  def create
    @transaction = Transaction.new(transaction_params)

    ActiveRecord::Base.transaction do
      if @transaction.save
        AuditLog.log_create(@transaction, request)
        redirect_to transactions_path, notice: "Transaction created."
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def edit
  end

  def update
    ActiveRecord::Base.transaction do
      # Track user modifications for rule-linked transactions
      if @transaction.recurring_rule.present? && transaction_params[:amount].present?
        new_amount = BigDecimal(transaction_params[:amount].to_s)
        @transaction.user_modified = true if @transaction.amount != new_amount
      end

      if @transaction.update(transaction_params)
        # Also mark linked transaction as user_modified for transfer consistency
        if @transaction.user_modified && @transaction.linked_transaction.present?
          @transaction.linked_transaction.update!(user_modified: true)
        end

        AuditLog.log_update(@transaction, request)
        redirect_to transactions_path, notice: "Transaction updated."
      else
        render :edit, status: :unprocessable_entity
      end
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
    # Capture where the user came from so we can redirect back after marking as actual
    @return_url = request.referer || transactions_path
  end

  def mark_actual
    # Validate required parameters
    unless params[:amount].present? && params[:original_sign].present?
      return redirect_back fallback_location: transactions_path, alert: "Missing required parameters."
    end

    # User enters positive amount, original_sign preserves the transaction type
    begin
      entered_amount = BigDecimal(params[:amount].to_s).abs
    rescue ArgumentError
      return redirect_back fallback_location: transactions_path, alert: "Invalid amount format."
    end

    if entered_amount <= 0
      return redirect_back fallback_location: transactions_path, alert: "Amount must be greater than zero."
    end

    sign = params[:original_sign].to_i

    unless sign == 1 || sign == -1
      return redirect_back fallback_location: transactions_path, alert: "Invalid sign parameter."
    end

    new_amount = entered_amount * sign

    ActiveRecord::Base.transaction do
      # The manage_transfer callback syncs status/amount to the linked transaction automatically
      @transaction.update!(status: :actual, amount: new_amount, user_modified: true)
      # Note: manage_transfer callback already syncs status/amount to linked_transaction,
      # but we need to also sync user_modified
      @transaction.linked_transaction&.update!(user_modified: true)
    end

    # Redirect to where the user originally came from
    return_url = params[:return_url].presence || transactions_path
    redirect_to return_url, notice: "Marked as actual with amount #{helpers.number_to_currency(entered_amount)}."
  rescue ActiveRecord::RecordInvalid => e
    return_url = params[:return_url].presence || transactions_path
    redirect_to return_url, alert: "Failed to update transaction: #{e.message}"
  end

  private

  def set_transaction
    @transaction = Transaction.includes(linked_transaction: :account).find(params[:id])
  end

  def transaction_params
    params.require(:transaction).permit(:account_id, :description, :amount, :date, :status, :category_id, :destination_account_id)
  end
end
