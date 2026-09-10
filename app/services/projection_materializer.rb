class ProjectionMaterializer
  HORIZON_MONTHS = 24

  class BatchError < StandardError
    attr_reader :failures

    def initialize(failures)
      @failures = failures
      super("Projection maintenance failed for recurring rule#{'s' if failures.many?}: #{failures.keys.join(', ')}")
    end
  end

  class << self
    def horizon(from: Date.current)
      from.advance(months: HORIZON_MONTHS)
    end

    def materialize(rule, through: horizon)
      return rule unless rule.active?

      dates = RecurrenceCalculator.new(rule).dates_between([ rule.anchor_date, Date.current ].max, through)
      existing_dates = rule.transactions.where(account_id: rule.account_id, date: dates).pluck(:date).to_set
      skipped_dates = dates_to_skip(rule)

      dates.each do |date|
        next if existing_dates.include?(date) || skipped_dates.include?(date)

        create_occurrence(rule, date)
      end

      rule
    end

    def materialize_all(through: horizon, account: nil)
      failures = {}
      scope = RecurringRule.active
      scope = scope.where(account: account).or(scope.where(destination_account: account)) if account

      scope.find_each do |rule|
        materialize(rule, through: through)
      rescue StandardError => error
        failures[rule.id] = error
        Rails.logger.error(
          "Projection maintenance failed for recurring rule #{rule.id}: #{error.class}: #{error.message}"
        )
      end

      raise BatchError, failures if failures.any?

      true
    end

    private

    def dates_to_skip(rule)
      modified_dates = rule.transactions.where(user_modified: true).pluck(:date).to_set
      original_dates = rule.transactions.where.not(original_date: nil).pluck(:original_date).to_set
      modified_dates | original_dates
    end

    def create_occurrence(rule, date)
      TransferCommand.create(
        account: rule.account,
        destination_account_id: rule.transfer? ? rule.destination_account_id : nil,
        recurring_rule: rule,
        description: rule.description,
        amount: signed_amount(rule),
        date: date,
        status: rule.is_estimated? ? :estimated : :actual,
        category: rule.category
      )
    rescue ActiveRecord::RecordNotUnique
      raise unless occurrence_complete?(rule, date)
    end

    def occurrence_complete?(rule, date)
      account_ids = rule.transfer? ? [ rule.account_id, rule.destination_account_id ] : [ rule.account_id ]
      rule.transactions.where(date: date, account_id: account_ids).distinct.count(:account_id) == account_ids.size
    end

    def signed_amount(rule)
      rule.income? ? rule.amount : -rule.amount
    end
  end
end
