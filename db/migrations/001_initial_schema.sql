-- Product-facing categories: the course/section a product belongs to on a
-- restaurant's menu (first course, second course, dessert, ...).
CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY,
  title_en TEXT NOT NULL,
  title_ru TEXT NOT NULL,
  title_uz TEXT NOT NULL,
  icon TEXT
);

-- The cuisine a restaurant serves (American, Italian, Japanese, ...).
CREATE TABLE IF NOT EXISTS cuisines (
  id INTEGER PRIMARY KEY,
  title_en TEXT NOT NULL,
  title_ru TEXT NOT NULL,
  title_uz TEXT NOT NULL,
  icon TEXT
);

-- The kind of food a restaurant is known for (Burgers, Pizza, Sushi, ...).
-- Distinct from `cuisines` (nationality) and `categories` (a product's course).
CREATE TABLE IF NOT EXISTS restaurant_categories (
  id INTEGER PRIMARY KEY,
  title_en TEXT NOT NULL,
  title_ru TEXT NOT NULL,
  title_uz TEXT NOT NULL,
  icon TEXT
);

CREATE TABLE IF NOT EXISTS restaurants (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  is_open BOOLEAN NOT NULL DEFAULT true,
  rating DOUBLE PRECISION,
  logo TEXT,
  address JSONB NOT NULL,
  image TEXT,
  cuisine INTEGER NOT NULL REFERENCES cuisines(id),
  category INTEGER NOT NULL REFERENCES restaurant_categories(id),
  start_time TEXT,
  end_time TEXT,
  description TEXT,
  phone_number TEXT,
  delivery_cost DOUBLE PRECISION,
  min_delivery_time INTEGER,
  max_delivery_time INTEGER,
  free_delivery_from DOUBLE PRECISION,
  product_categories JSONB
);

CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY,
  restaurant_id INTEGER NOT NULL REFERENCES restaurants(id),
  category INTEGER NOT NULL REFERENCES categories(id),
  price DOUBLE PRECISION NOT NULL,
  status TEXT NOT NULL,
  title_en TEXT NOT NULL,
  title_ru TEXT,
  title_uz TEXT,
  image TEXT,
  description TEXT,
  unit TEXT
);

-- For databases created before products carried a weight unit. Existing rows
-- keep a NULL unit until backfilled.
ALTER TABLE products ADD COLUMN IF NOT EXISTS unit TEXT;

CREATE TABLE IF NOT EXISTS users (
  uid TEXT PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  photo_url TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS orders (
  id TEXT PRIMARY KEY,
  user_id TEXT REFERENCES users(uid),
  cost DOUBLE PRECISION NOT NULL,
  status TEXT NOT NULL,
  order_time TIMESTAMPTZ NOT NULL,
  restaurant_info JSONB NOT NULL,
  products JSONB NOT NULL,
  delivery_address JSONB,
  courier JSONB,
  payment_detail JSONB
);

-- Orders are always listed for one user, newest first.
CREATE INDEX IF NOT EXISTS orders_user_id_order_time_idx
  ON orders (user_id, order_time DESC);

-- For databases created before orders were attributed to a user. Existing rows
-- keep a NULL user_id and are therefore invisible to the per-user listing.
ALTER TABLE orders ADD COLUMN IF NOT EXISTS user_id TEXT REFERENCES users(uid);

-- One row per issued refresh token. A refresh token carries this row's id as
-- its `jti` claim, which is what makes it revocable: without a matching
-- unrevoked row, a correctly signed token is still refused.
--
-- family_id links a rotation chain. Rotating a token revokes it and issues a
-- successor in the same family, so presenting an already-rotated token means
-- the chain leaked and the whole family is revoked.
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  family_id TEXT NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  replaced_by TEXT
);

CREATE INDEX IF NOT EXISTS refresh_tokens_family_id_idx
  ON refresh_tokens (family_id);

-- Supports pruning; rows are not removed when they expire, only when swept.
CREATE INDEX IF NOT EXISTS refresh_tokens_expires_at_idx
  ON refresh_tokens (expires_at);

-- One row per user/item favorite. item_id is not a foreign key: it points at
-- either restaurants or products depending on item_type, and PostgreSQL has
-- no polymorphic FK, so existence is instead checked at the application layer
-- before a row is written.
CREATE TABLE IF NOT EXISTS favorites (
  user_id TEXT NOT NULL REFERENCES users(uid) ON DELETE CASCADE,
  item_type TEXT NOT NULL CHECK (item_type IN ('restaurant', 'product')),
  item_id INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (user_id, item_type, item_id)
);

-- Favorites are always listed for one user and type, newest first.
CREATE INDEX IF NOT EXISTS favorites_user_id_item_type_idx
  ON favorites (user_id, item_type, created_at DESC);
