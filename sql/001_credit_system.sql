-- PostgreSQL migration: replace balance model with credit model (safer/idempotent)

BEGIN;

-- 0) Migration marker table for idempotent data backfill
CREATE TABLE IF NOT EXISTS schema_migrations_meta (
  key TEXT PRIMARY KEY,
  applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 1) Add credits column to users if missing
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS credits BIGINT NOT NULL DEFAULT 0;

-- 1.1) Keep credits non-negative
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'users_credits_non_negative'
      AND conrelid = 'users'::regclass
  ) THEN
    ALTER TABLE users
      ADD CONSTRAINT users_credits_non_negative CHECK (credits >= 0);
  END IF;
END
$$;

-- 2) Create credit ledger table
CREATE TABLE IF NOT EXISTS credit_ledger (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delta BIGINT NOT NULL,
  reason TEXT NOT NULL,
  reference_id TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_credit_ledger_user_id_created_at
  ON credit_ledger (user_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS uq_credit_ledger_migration_reference
  ON credit_ledger (user_id, reason, reference_id)
  WHERE reason = 'migration_backfill' AND reference_id = 'users.balance';

-- 3) Backfill exactly once when users.balance exists
DO $$
DECLARE
  has_balance_column BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'users'
      AND column_name = 'balance'
  ) INTO has_balance_column;

  IF has_balance_column
     AND NOT EXISTS (
       SELECT 1 FROM schema_migrations_meta
       WHERE key = 'balance_to_credits_backfill_v1'
     ) THEN

    -- initialize credits only for rows still at default value
    EXECUTE $SQL$
      UPDATE users
      SET credits = COALESCE(balance, 0)
      WHERE COALESCE(credits, 0) = 0
    $SQL$;

    EXECUTE $SQL$
      INSERT INTO credit_ledger (user_id, delta, reason, reference_id)
      SELECT u.id, COALESCE(u.balance, 0), 'migration_backfill', 'users.balance'
      FROM users u
      WHERE COALESCE(u.balance, 0) <> 0
        AND NOT EXISTS (
          SELECT 1
          FROM credit_ledger l
          WHERE l.user_id = u.id
            AND l.reason = 'migration_backfill'
            AND l.reference_id = 'users.balance'
        )
    $SQL$;

    INSERT INTO schema_migrations_meta (key)
    VALUES ('balance_to_credits_backfill_v1')
    ON CONFLICT (key) DO NOTHING;
  END IF;
END
$$;

-- 4) Remove old balance artifacts (safe if already removed)
DROP TABLE IF EXISTS balance_transactions;
ALTER TABLE users DROP COLUMN IF EXISTS balance;

COMMIT;
