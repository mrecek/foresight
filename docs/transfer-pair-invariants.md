# Transfer-pair invariants

An unlinked transaction is a regular financial record. A linked transfer is
exactly two distinct transactions that point to each other. The two sides must
use different accounts, have inverse amounts, and share description, date,
status, category, recurring rule, user-modified state, and original date.
Self-links, missing or one-way counterparts, many-to-one graphs, same-account
pairs, and mismatched pair data are invalid.

Run `bin/transfers` for a read-only audit. It exits unsuccessfully and reports
every affected row when corruption exists. Run `bin/transfers --repair` only
after taking a backup. Repair is deliberately conservative: an otherwise-valid
one-way pair gains its missing back-link; ambiguous graphs or pairs with
financial/metadata disagreement are unlinked into independent regular
transactions. No transaction row or financial value is deleted or rewritten.
Every link change is reported, and rerunning repair is a no-op.

The migration preflight refuses to advance while corruption remains. This makes
the repair an explicit operator decision instead of silently choosing which
side of conflicting financial data is authoritative.

All production lifecycle paths use `TransferCommand`; `Transaction` callbacks
never create, synchronize, unlink, or delete another financial row. Manual and
recurring creation, edits, conversion to a regular transaction, mark-actual,
pair deletion, recurring cleanup, account reconciliation, and account deletion
therefore share the same database transaction boundary. Reconciliation and
account deletion intentionally retain the other account's historical side as an
unlinked regular transaction; explicit transfer deletion removes both sides.
