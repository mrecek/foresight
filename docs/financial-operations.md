# Financial operations

Controllers translate HTTP parameters and render operation results. Financial
operations own validation, transaction coordination and audit events. Jobs and
other callers use the same interfaces without an HTTP request.

| Operation | Entry point | Focused tests |
| --- | --- | --- |
| Edit a transaction | `TransactionChange.update(transaction, attributes:, audit_context:)` | `test/services/transaction_change_test.rb` |
| Confirm an actual amount | `TransactionChange.confirm_actual(transaction, amount:, audit_context:)` | `test/services/transaction_change_test.rb` |
| Reconcile an account | `AccountReconciliation.call(account:, attributes:, include_today:, audit_context:)` | `test/services/account_reconciliation_test.rb` |

`AuditContext` contains only `remote_ip` and `user_agent`. HTTP callers construct
it with `AuditContext.from_request(request)`; other callers supply the metadata
directly. Financial changes and their audit event commit in the same database
transaction. A persistence or audit exception aborts the operation.

Invalid financial input raises `ActiveRecord::RecordInvalid` with errors on the
supplied record. Callers render those errors and must not treat the record's
in-memory attributes as proof of a committed change after an exception. Financial
amounts accept a signed decimal with at most ten whole digits and two fractional
digits. Values are parsed as `BigDecimal`; non-finite values and excess precision
are rejected. Dates use ISO calendar notation.

Transaction edits track user changes and original occurrence dates for recurring
rules. Actual confirmation derives direction from the stored transaction, and
accepts a magnitude independently of any browser sign field. Incoming transfer
edits require review from the sending side; actual confirmation can operate on
either side. `TransferCommand` owns paired-row persistence and mirrors financial
and occurrence metadata within the transaction. See
[transfer-pair invariants](transfer-pair-invariants.md).

Reconciliation accepts an explicit boolean `include_today`. It removes entries
before the balance date, including that date only when requested, and returns the
account and deleted count. Removing one transfer side for reconciliation retains
the other account's financial history as an unlinked record. Explicit transfer
deletion removes both sides. Repeating a reconciliation does not repeat deletions
of rows that are already absent.

## Recurring occurrence removals

Explicit transaction deletion and reconciliation persist `OccurrenceExclusion`
records for both the removed date and any original date of a moved occurrence.
Exclusions belong to the recurring rule and suppress regeneration of the entire
occurrence, including a transfer pair. Reconciliation retains the other account's
unlinked history; automatic rule updates preserve excluded dates as well.
Deleting a rule removes its exclusions. Automatic projection rebuilding does
not create exclusions, so ordinary rule changes can regenerate future entries.

`TransferCommand.destroy(..., exclude_occurrence: true)` records intentional
removals atomically with row deletion and audit. Internal rebuild and account/rule
cleanup use the default `false`. `TransferCommand.create_occurrence` checks for
exclusions inside its persistence transaction, including busy retries.

Moving an occurrence onto an occupied rule/account/date returns a validation
error and leaves the stored rows unchanged. A uniqueness conflict during the save
is translated to the same validation outcome; the database constraint remains
the final concurrency guard.
