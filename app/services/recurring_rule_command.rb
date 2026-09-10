class RecurringRuleCommand
  PROJECTION_FIELDS = %w[
    description frequency anchor_date day_of_month day_of_week amount rule_type
    account_id destination_account_id is_estimated
  ].freeze

  class << self
    def create(rule, &audit)
      RecurringRule.transaction do
        rule.save!
        ProjectionMaterializer.materialize(rule)
        audit&.call(rule)
        rule
      end
    end

    def update(rule, attributes, &audit)
      RecurringRule.transaction do
        rule.update!(attributes)
        apply_projection_changes(rule)
        audit&.call(rule)
        rule
      end
    end

    def destroy(rule, &audit)
      RecurringRule.transaction do
        destroy_occurrences(rule, rule.transactions)
        audit&.call(rule)
        rule.destroy!
      end
    end

    private

    def apply_projection_changes(rule)
      if (rule.previous_changes.keys & PROJECTION_FIELDS).any?
        destroy_future_automatic_occurrences(rule)
        ProjectionMaterializer.materialize(rule)
      elsif rule.saved_change_to_active?
        rule.active? ? ProjectionMaterializer.materialize(rule) : destroy_future_automatic_occurrences(rule)
      elsif rule.saved_change_to_category_id?
        update_future_estimated_categories(rule)
      end
    end

    def destroy_future_automatic_occurrences(rule)
      scope = rule.transactions
        .where(account_id: rule.account_id)
        .where("date >= ?", Date.current)
        .not_user_modified
      destroy_occurrences(rule, scope)
    end

    def update_future_estimated_categories(rule)
      rule.transactions
        .where(account_id: rule.account_id, status: :estimated)
        .where("date >= ?", Date.current)
        .not_user_modified
        .find_each do |transaction|
          TransferCommand.update(transaction, category_id: rule.category_id)
        end
    end

    def destroy_occurrences(_rule, scope)
      scope.ids.each do |transaction_id|
        transaction = Transaction.find_by(id: transaction_id)
        TransferCommand.destroy(transaction) if transaction
      end
    end
  end
end
