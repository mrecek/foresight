class InitialSetup < ActiveRecord::Migration[8.1]
  def change
    # 1. Create tables without dependencies
    create_table :accounts do |t|
      t.string :name, null: false
      t.integer :account_type, null: false, default: 0
      t.decimal :current_balance, precision: 12, scale: 2, null: false, default: 0.0
      t.date :balance_date, null: false
      t.decimal :warning_threshold, precision: 12, scale: 2, null: false, default: 300.0

      t.timestamps
    end

    create_table :settings do |t|
      t.integer :default_view_months, null: false, default: 6
      t.string :auth_username
      t.string :auth_password_digest
      t.integer :session_timeout_minutes, null: false, default: 30

      t.timestamps
    end

    create_table :category_groups do |t|
      t.string :name, null: false
      t.string :color, null: false
      t.integer :display_order, null: false, default: 0

      t.timestamps
    end
    add_index :category_groups, :name, unique: true

    create_table :audit_logs do |t|
      t.string :action, null: false
      t.string :resource_type
      t.integer :resource_id
      t.text :details
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
    add_index :audit_logs, [ :resource_type, :resource_id ]

    # 2. Create tables with FK dependencies
    create_table :categories do |t|
      t.references :category_group, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :display_order, null: false, default: 0

      t.timestamps
    end
    add_index :categories, [ :category_group_id, :name ], unique: true
    add_index :categories, [ :category_group_id, :display_order ]

    # 3. Create tables with multiple FKs including self-references
    create_table :recurring_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :destination_account, foreign_key: { to_table: :accounts }
      t.references :category, foreign_key: true
      t.integer :rule_type, null: false, default: 0
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :frequency, null: false, default: 0
      t.date :anchor_date, null: false
      t.integer :day_of_month
      t.integer :day_of_week
      t.boolean :active, null: false, default: true
      t.boolean :is_estimated, null: false, default: true

      t.timestamps
    end

    # SQLite triggers to prevent self-transfers (rule_type 2 = transfer)
    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE TRIGGER enforce_different_transfer_accounts_insert
          BEFORE INSERT ON recurring_rules
          WHEN NEW.rule_type = 2 AND NEW.account_id = NEW.destination_account_id
          BEGIN
            SELECT RAISE(ABORT, 'Transfer source and destination accounts must be different');
          END
        SQL

        execute <<-SQL
          CREATE TRIGGER enforce_different_transfer_accounts_update
          BEFORE UPDATE ON recurring_rules
          WHEN NEW.rule_type = 2 AND NEW.account_id = NEW.destination_account_id
          BEGIN
            SELECT RAISE(ABORT, 'Transfer source and destination accounts must be different');
          END
        SQL
      end

      dir.down do
        execute "DROP TRIGGER IF EXISTS enforce_different_transfer_accounts_insert"
        execute "DROP TRIGGER IF EXISTS enforce_different_transfer_accounts_update"
      end
    end

    create_table :transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :recurring_rule, foreign_key: true
      t.references :linked_transaction, foreign_key: { to_table: :transactions }
      t.references :category, foreign_key: true
      t.date :date, null: false
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.integer :status, null: false, default: 0
      t.boolean :user_modified, default: false, null: false

      t.timestamps
    end
    add_index :transactions, :date
    add_index :transactions, [ :account_id, :date ]
    add_index :transactions, [ :recurring_rule_id, :account_id, :date ],
              unique: true,
              where: "recurring_rule_id IS NOT NULL",
              name: "index_transactions_on_rule_account_date_unique"
  end
end
