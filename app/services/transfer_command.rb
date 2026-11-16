class TransferCommand
  MAX_BUSY_ATTEMPTS = 5
  MIRRORED_FIELDS = %i[description date status category_id recurring_rule_id user_modified original_date].freeze

  class << self
    def create(attributes, &audit)
      persist(attributes, &audit)
    end

    def create_occurrence(attributes)
      persist(attributes, respect_exclusions: true)
    end

    def update(transaction, attributes, &audit)
      with_busy_retry do
        Transaction.transaction do
          values, explicit_destination = split_destination(attributes)
          destination_supplied = attributes.to_h.with_indifferent_access.key?(:destination_account_id)
          destination_id = destination_supplied ? explicit_destination : transaction.linked_transaction&.account_id
          transaction.destination_account_id = destination_id if destination_supplied
          transaction.update!(values)
          if destination_supplied && destination_id.blank?
            unlink_and_destroy_counterpart!(transaction)
          elsif destination_id.present?
            link_pair!(transaction, destination_id)
          end
          audit&.call(transaction)
          transaction
        end
      end
    end

    def destroy(transaction, pair: true, exclude_occurrence: false, &audit)
      with_busy_retry do
        Transaction.transaction do
          counterpart = transaction.linked_transaction
          if exclude_occurrence
            OccurrenceExclusion.record!(transaction)
            OccurrenceExclusion.record!(counterpart) if pair && counterpart
          end
          audit&.call(transaction)
          transaction.update_column(:linked_transaction_id, nil) if counterpart
          counterpart&.update_column(:linked_transaction_id, nil)
          counterpart&.destroy! if pair
          transaction.destroy!
        end
      end
    end

    private

    def persist(attributes, respect_exclusions: false, &audit)
      with_busy_retry do
        Transaction.transaction(requires_new: true) do
          values, destination_id = split_destination(attributes)
          # Recheck inside the write transaction/retry boundary so concurrent
          # reconciliation cannot be followed by a stale projection insert.
          if respect_exclusions && OccurrenceExclusion.exists?(
            recurring_rule_id: values[:recurring_rule]&.id, date: values[:date])
            next
          end
          source = Transaction.new(values)
          source.destination_account_id = destination_id
          source.save!
          link_pair!(source, destination_id) if destination_id.present?
          audit&.call(source)
          source
        end
      end
    end

    def split_destination(attributes)
      values = attributes.to_h.with_indifferent_access
      destination = values.delete(:destination_account_id)
      [ values, destination ]
    end

    def link_pair!(source, destination_id)
      counterpart = source.linked_transaction || Transaction.new
      counterpart.assign_attributes(
        account_id: destination_id,
        amount: -source.amount,
        **MIRRORED_FIELDS.to_h { |field| [ field, source.public_send(field) ] }
      )
      counterpart.save!
      source.update_column(:linked_transaction_id, counterpart.id) unless source.linked_transaction_id == counterpart.id
      counterpart.update_column(:linked_transaction_id, source.id) unless counterpart.linked_transaction_id == source.id
      source.association(:linked_transaction).reset
    end

    def unlink_and_destroy_counterpart!(source)
      counterpart = source.linked_transaction
      return unless counterpart
      source.update_column(:linked_transaction_id, nil)
      counterpart.update_column(:linked_transaction_id, nil)
      counterpart.destroy!
      source.association(:linked_transaction).reset
    end

    def with_busy_retry
      attempts = 0
      begin
        attempts += 1
        yield
      rescue ActiveRecord::StatementInvalid => error
        raise unless error.cause.is_a?(SQLite3::BusyException) && attempts < MAX_BUSY_ATTEMPTS
        sleep(0.05 * attempts)
        retry
      end
    end
  end
end
