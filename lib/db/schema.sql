CREATE TABLE IF NOT EXISTS categories (
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
  category INTEGER NOT NULL REFERENCES categories(id),
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
  description TEXT
);

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

INSERT INTO categories (id, title_en, title_ru, title_uz, icon) VALUES
  (1, 'Burgers', 'Бургеры', 'Burgerlar', 'https://picsum.photos/seed/burgers/200/200'),
  (2, 'Pizza', 'Пицца', 'Pizza', 'https://picsum.photos/seed/pizza/200/200'),
  (3, 'Sushi', 'Суши', 'Sushi', 'https://picsum.photos/seed/sushi/200/200')
ON CONFLICT (id) DO NOTHING;

INSERT INTO restaurants (
  id, name, is_open, rating, logo, address, image, category, start_time,
  end_time, description, phone_number, delivery_cost, min_delivery_time,
  max_delivery_time, free_delivery_from, product_categories
) VALUES
  (
    1, 'Burger House', true, 4.5, 'https://picsum.photos/seed/bh_logo/100/100',
    '{"latitude":41.2995,"longitude":69.2401,"type":"other","street":"123 Amir Temur Ave","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/burgerhouse/600/300', 1, '09:00', '23:00',
    'Best smash burgers in town', '+998901234567', 5000.0, 20, 40, 50000.0, '[1]'
  ),
  (
    2, 'Pizza Palace', true, 4.2, 'https://picsum.photos/seed/pp_logo/100/100',
    '{"latitude":41.3111,"longitude":69.2797,"type":"other","street":"456 Navoi St","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/pizzapalace/600/300', 2, '10:00', '22:00',
    'Authentic Italian pizza baked in a wood oven', '+998907654321', 3000.0, 30, 50, 80000.0, '[2]'
  ),
  (
    3, 'Sushi World', false, 4.8, 'https://picsum.photos/seed/sw_logo/100/100',
    '{"latitude":41.2887,"longitude":69.2126,"type":"other","street":"789 Yunusabad Blvd","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/sushiworld/600/300', 3, '11:00', '21:00',
    'Premium Japanese cuisine made fresh daily', '+998909876543', 7000.0, 40, 60, 100000.0, '[3]'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO products (
  id, restaurant_id, category, price, status, title_en, title_ru, title_uz, image, description
) VALUES
  (1, 1, 1, 25000.0, 'available', 'Classic Burger', 'Классический бургер', 'Klassik burger', 'https://picsum.photos/seed/classic_burger/300/300', 'Beef patty with lettuce, tomato, and cheese'),
  (2, 1, 1, 35000.0, 'available', 'Double Smash Burger', 'Двойной смэш бургер', 'Ikki qatlamli burger', 'https://picsum.photos/seed/double_burger/300/300', 'Two smashed beef patties with special sauce'),
  (3, 1, 1, 12000.0, 'available', 'Crispy Fries', 'Хрустящая картошка', 'Qovurilgan kartoshka', 'https://picsum.photos/seed/fries/300/300', 'Golden crispy french fries'),
  (4, 2, 2, 45000.0, 'available', 'Margherita Pizza', 'Пицца Маргарита', 'Margarita pizza', 'https://picsum.photos/seed/margherita/300/300', 'Classic tomato sauce with fresh mozzarella'),
  (5, 2, 2, 55000.0, 'available', 'Pepperoni Pizza', 'Пицца Пепперони', 'Pepperoni pizza', 'https://picsum.photos/seed/pepperoni/300/300', 'Loaded with spicy pepperoni slices'),
  (6, 2, 2, 15000.0, 'available', 'Caesar Salad', 'Салат Цезарь', 'Sezar salati', 'https://picsum.photos/seed/caesar/300/300', 'Romaine lettuce with caesar dressing and croutons'),
  (7, 3, 3, 35000.0, 'available', 'Salmon Roll', 'Ролл с лососем', 'Salmon roll', 'https://picsum.photos/seed/salmon_roll/300/300', 'Fresh salmon with cucumber and avocado'),
  (8, 3, 3, 40000.0, 'available', 'Dragon Roll', 'Ролл Дракон', 'Dragon roll', 'https://picsum.photos/seed/dragon_roll/300/300', 'Shrimp tempura topped with avocado'),
  (9, 3, 3, 28000.0, 'available', 'Miso Soup', 'Мисо суп', 'Miso sho''rva', 'https://picsum.photos/seed/miso/300/300', 'Traditional Japanese miso soup with tofu')
ON CONFLICT (id) DO NOTHING;
