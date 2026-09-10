class EnforceTransferLinkShape < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :transactions,
      "linked_transaction_id IS NULL OR linked_transaction_id != id",
      name: "transactions_no_self_link"
    add_index :transactions, :linked_transaction_id,
      unique: true,
      where: "linked_transaction_id IS NOT NULL",
      name: "index_transactions_on_unique_linked_transaction"
  end
end
