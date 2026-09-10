class TransferPairIntegrity
  FIELDS = %i[description date status category_id recurring_rule_id user_modified original_date].freeze
  Issue = Data.define(:type, :transaction_ids, :details)

  def self.check
    new.check
  end

  def self.repair
    new.repair
  end

  def initialize(scope = Transaction.unscoped)
    @scope = scope
  end

  def check
    rows = snapshots
    incoming = rows.values.filter_map(&:linked_transaction_id).tally
    issues = []

    incoming.select { |_id, count| count > 1 }.each do |target, count|
      sources = rows.values.select { |row| row.linked_transaction_id == target }.map(&:id)
      issues << Issue.new(type: :many_to_one, transaction_ids: (sources + [ target ]).uniq.sort, details: "#{count} rows link to transaction #{target}")
    end

    rows.each_value do |row|
      linked_id = row.linked_transaction_id
      next unless linked_id
      if linked_id == row.id
        issues << Issue.new(type: :self_link, transaction_ids: [ row.id ], details: "transaction links to itself")
        next
      end

      counterpart = rows[linked_id]
      unless counterpart
        issues << Issue.new(type: :missing_counterpart, transaction_ids: [ row.id, linked_id ], details: "linked transaction does not exist")
        next
      end

      if counterpart.linked_transaction_id != row.id
        issues << Issue.new(type: :one_way_link, transaction_ids: [ row.id, counterpart.id ].sort, details: "counterpart does not link back")
      end
      next unless row.id < counterpart.id

      if row.account_id == counterpart.account_id
        issues << Issue.new(type: :invalid_accounts, transaction_ids: [ row.id, counterpart.id ], details: "both sides use account #{row.account_id}")
      end
      mismatches = mismatched_fields(row, counterpart)
      if mismatches.delete(:amount)
        issues << Issue.new(type: :amount_mismatch, transaction_ids: [ row.id, counterpart.id ], details: "amounts are not exact inverses")
      end
      if mismatches.any?
        issues << Issue.new(type: :metadata_mismatch, transaction_ids: [ row.id, counterpart.id ], details: "mismatched #{mismatches.join(', ')}")
      end
    end

    issues.uniq { |issue| [ issue.type, issue.transaction_ids ] }
  end

  def repair
    before = check
    return [ before, [] ] if before.empty?

    rows = snapshots
    changes = []
    components(rows).each do |ids|
      component = ids.filter_map { |id| rows[id] }
      next if component.none?(&:linked_transaction_id)

      if repairable_one_way?(component, rows)
        first, second = component
        source, target = first.linked_transaction_id == second.id ? [ first, second ] : [ second, first ]
        update_link(target.id, source.id, changes) if target.linked_transaction_id != source.id
      elsif valid_pair?(component)
        next
      else
        component.each { |row| update_link(row.id, nil, changes) if row.linked_transaction_id }
      end
    end
    [ before, changes ]
  end

  private

  Snapshot = Data.define(:id, :linked_transaction_id, :account_id, :amount, *FIELDS)

  def snapshots
    columns = [ :id, :linked_transaction_id, :account_id, :amount, *FIELDS ]
    @scope.pluck(*columns).to_h { |values| [ values.first, Snapshot.new(**columns.zip(values).to_h) ] }
  end

  def mismatched_fields(left, right)
    mismatches = []
    mismatches << :amount unless left.amount == -right.amount
    FIELDS.each { |field| mismatches << field unless left.public_send(field) == right.public_send(field) }
    mismatches
  end

  def valid_pair?(component)
    return false unless component.size == 2
    left, right = component
    left.linked_transaction_id == right.id && right.linked_transaction_id == left.id &&
      left.account_id != right.account_id && mismatched_fields(left, right).empty?
  end

  def repairable_one_way?(component, rows)
    return false unless component.size == 2
    left, right = component
    links = [ left.linked_transaction_id == right.id, right.linked_transaction_id == left.id ]
    links.count(true) == 1 && left.account_id != right.account_id && mismatched_fields(left, right).empty? &&
      rows.values.count { |row| [ left.id, right.id ].include?(row.linked_transaction_id) } == 1
  end

  def components(rows)
    adjacency = Hash.new { |hash, key| hash[key] = [] }
    rows.each_value do |row|
      next unless row.linked_transaction_id
      adjacency[row.id] << row.linked_transaction_id
      adjacency[row.linked_transaction_id] << row.id
    end
    seen = {}
    adjacency.keys.map do |start|
      next if seen[start]
      stack = [ start ]
      component = []
      until stack.empty?
        id = stack.pop
        next if seen[id]
        seen[id] = true
        component << id
        stack.concat(adjacency[id])
      end
      component
    end.compact
  end

  def update_link(id, linked_id, changes)
    transaction = @scope.find(id)
    previous = transaction.linked_transaction_id
    transaction.update_column(:linked_transaction_id, linked_id)
    changes << { transaction_id: id, from: previous, to: linked_id }
  end
end
