class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
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
    add_index :audit_logs, [ :resource_type, :resource_id ]
    add_index :audit_logs, :created_at
  end
end
