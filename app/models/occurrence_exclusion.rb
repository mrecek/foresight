# Intentional removals outlive transaction rows and suppress the whole occurrence,
# including regeneration of a transfer side whose other account retains history.
class OccurrenceExclusion < ApplicationRecord
  belongs_to :recurring_rule
  validates :date, presence: true

  def self.record!(transaction)
    return unless transaction.recurring_rule_id

    [ transaction.date, transaction.original_date ].compact.uniq.each do |date|
      create_or_find_by!(recurring_rule_id: transaction.recurring_rule_id, date: date)
    end
  end
end
