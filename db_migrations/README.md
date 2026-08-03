# Database migrations

`schema.sql` at the repo root always describes the **current** schema and is
what a fresh installation runs once. Whenever `schema.sql` changes, a numbered
migration is added here providing the upgrade path for databases created from
an earlier schema.

Conventions:

- Files are numbered in order: `01_...sql`, `02_...sql`, ...
- Every migration is **idempotent**: it checks `information_schema` (or uses
  `IF NOT EXISTS`) before altering, so re-running it — or running it against a
  fresh, already-current database — is a safe no-op.
- Apply with: `mysql -u USER -p neon_nebula < db_migrations/NN_name.sql`
  (or paste into phpMyAdmin's SQL tab), in ascending order.
