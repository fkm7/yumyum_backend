-- Append to schema.sql (or run once by hand against an existing database).

-- One row per saved delivery address. Addresses are always looked up scoped
-- to their owning user; there is no shared/global address.
CREATE TABLE IF NOT EXISTS addresses (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'other',
  label TEXT,
  street TEXT NOT NULL,
  city TEXT NOT NULL,
  country TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL
);

-- Addresses are always listed for one user, newest first.
CREATE INDEX IF NOT EXISTS addresses_user_id_idx
  ON addresses (user_id, created_at DESC);

-- Enforces at most one default address per user; the repository unsets the
-- previous default inside the same transaction that sets a new one, but this
-- is the backstop against a concurrent write racing past that.
CREATE UNIQUE INDEX IF NOT EXISTS addresses_user_default_idx
  ON addresses (user_id) WHERE is_default;

-- One row per saved payment method. No PAN or CVV is ever stored: `brand`
-- and `last4` are display-only. A real gateway integration (Stripe, etc.)
-- would add a `provider_token` column carrying the tokenized reference
-- instead of card details.
CREATE TABLE IF NOT EXISTS payment_methods (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  type TEXT NOT NULL,
  brand TEXT,
  last4 TEXT,
  expiry_month INTEGER,
  expiry_year INTEGER,
  is_default BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX IF NOT EXISTS payment_methods_user_id_idx
  ON payment_methods (user_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS payment_methods_user_default_idx
  ON payment_methods (user_id) WHERE is_default;

-- Orders now reference the saved address/payment method that was used, in
-- addition to keeping a point-in-time snapshot in delivery_address /
-- payment_detail (the same pattern restaurant_info already uses for
-- restaurants: the FK can go stale or be deleted, the snapshot cannot).
ALTER TABLE orders ADD COLUMN IF NOT EXISTS address_id TEXT
  REFERENCES addresses(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method_id TEXT
  REFERENCES payment_methods(id);
