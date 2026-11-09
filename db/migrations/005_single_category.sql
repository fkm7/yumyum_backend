-- Brings a database from before the single category table up to the schema
-- in 001: production, whose tables were created by the old `schema.sql`.
--
-- A database created by 001 has none of the old tables, so the guard below
-- makes this a no-op there. On an old database, 001's `IF NOT EXISTS` left the
-- previous layout in place, and this converts it:
--
--   * `categories` (a product's course: First course, Second course, Dessert)
--     and `restaurant_categories` (Burgers, Pizza, Sushi, ...) merge into one
--     `categories` table of food types;
--   * every product is moved onto a food type;
--   * restaurants lose `category` and `product_categories`, which are now
--     derived from their products;
--   * picsum.photos placeholder images point at `public/assets/` instead.
DO $$
DECLARE
  fk RECORD;
BEGIN
  IF to_regclass('public.restaurant_categories') IS NULL THEN
    RETURN;
  END IF;

  -- Keep the old course categories around under another name until products
  -- have been moved off them.
  ALTER TABLE categories RENAME TO legacy_product_categories;
  ALTER INDEX IF EXISTS categories_pkey
    RENAME TO legacy_product_categories_pkey;

  CREATE TABLE categories (
    id INTEGER PRIMARY KEY,
    title_en TEXT NOT NULL,
    title_ru TEXT NOT NULL,
    title_uz TEXT NOT NULL,
    icon TEXT
  );

  -- The food types already exist as restaurant categories; keeping their ids
  -- keeps restaurants' old `category` values valid for the fallback below.
  INSERT INTO categories (id, title_en, title_ru, title_uz, icon)
  SELECT id, title_en, title_ru, title_uz, icon FROM restaurant_categories;

  -- Food types that only existed as a product course, or not at all.
  INSERT INTO categories (id, title_en, title_ru, title_uz, icon)
  SELECT v.id, v.title_en, v.title_ru, v.title_uz, NULL
  FROM (VALUES
    (7, 'Dessert', 'Десерт', 'Shirinlik'),
    (8, 'Soups', 'Супы', 'Sho''rvalar'),
    (9, 'Sides', 'Закуски', 'Gazaklar')
  ) AS v (id, title_en, title_ru, title_uz)
  WHERE NOT EXISTS (SELECT 1 FROM categories c WHERE c.title_en = v.title_en);

  -- Icons shipped in `public/assets/categories/`, matched by name.
  UPDATE categories c SET icon = v.icon
  FROM (VALUES
    ('All', '/assets/categories/all.svg'),
    ('Burgers', '/assets/categories/burger.svg'),
    ('Pizza', '/assets/categories/pizza.svg'),
    ('Sushi', '/assets/categories/sushi.svg'),
    ('Salads', '/assets/categories/salad.svg'),
    ('Pasta', '/assets/categories/spaghetti.svg'),
    ('Grill', '/assets/categories/grill.svg'),
    ('Dessert', '/assets/categories/cupcake.svg'),
    ('Soups', '/assets/categories/soup.svg'),
    ('Sides', '/assets/categories/sides.svg')
  ) AS v (title_en, icon)
  WHERE c.title_en = v.title_en;

  -- The old schema's constraint name is not guaranteed, so drop whatever
  -- foreign key sits on products.category.
  FOR fk IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_attribute att
      ON att.attrelid = con.conrelid AND att.attnum = ANY (con.conkey)
    WHERE con.conrelid = 'products'::regclass
      AND con.contype = 'f'
      AND att.attname = 'category'
  LOOP
    EXECUTE format('ALTER TABLE products DROP CONSTRAINT %I', fk.conname);
  END LOOP;

  -- Re-point every product at a food category, first match wins:
  --   1. the demo catalog's products, by name;
  --   2. a course with a food-type equivalent (First course → Soups,
  --      Dessert → Dessert);
  --   3. otherwise the food type its restaurant was filed under.
  -- If all three came back NULL, the NOT NULL column aborts the migration.
  UPDATE products p
  SET category = COALESCE(
    (
      SELECT c.id FROM categories c
      WHERE c.title_en = CASE p.title_en
        WHEN 'Classic Burger' THEN 'Burgers'
        WHEN 'Double Smash Burger' THEN 'Burgers'
        WHEN 'Ribeye Burger' THEN 'Burgers'
        WHEN 'BBQ Bacon Burger' THEN 'Burgers'
        WHEN 'Margherita Pizza' THEN 'Pizza'
        WHEN 'Pepperoni Pizza' THEN 'Pizza'
        WHEN 'Quattro Formaggi' THEN 'Pizza'
        WHEN 'Diavola Pizza' THEN 'Pizza'
        WHEN 'Salmon Roll' THEN 'Sushi'
        WHEN 'Dragon Roll' THEN 'Sushi'
        WHEN 'Caesar Salad' THEN 'Salads'
        WHEN 'Miso Soup' THEN 'Soups'
        WHEN 'Crispy Fries' THEN 'Sides'
        WHEN 'Onion Rings' THEN 'Sides'
        WHEN 'Garlic Bread' THEN 'Sides'
      END
    ),
    (
      SELECT c.id FROM legacy_product_categories pc
      JOIN categories c ON c.title_en = CASE pc.title_en
        WHEN 'First course' THEN 'Soups'
        WHEN 'Dessert' THEN 'Dessert'
      END
      WHERE pc.id = p.category
    ),
    (SELECT r.category FROM restaurants r WHERE r.id = p.restaurant_id)
  );

  ALTER TABLE products ADD CONSTRAINT products_category_fkey
    FOREIGN KEY (category) REFERENCES categories(id);

  -- Both are derived from products now.
  ALTER TABLE restaurants DROP COLUMN IF EXISTS category;
  ALTER TABLE restaurants DROP COLUMN IF EXISTS product_categories;

  DROP TABLE restaurant_categories;
  DROP TABLE legacy_product_categories;

  -- picsum.photos placeholders from the demo catalog → copies shipped in
  -- `public/assets/`, matched on the exact old URL so anything already
  -- changed is left alone.
  UPDATE cuisines SET icon = '/assets/cuisines/american.jpg' WHERE icon = 'https://picsum.photos/seed/american/200/200';
  UPDATE cuisines SET icon = '/assets/cuisines/italian.jpg' WHERE icon = 'https://picsum.photos/seed/italian/200/200';
  UPDATE cuisines SET icon = '/assets/cuisines/japanese.jpg' WHERE icon = 'https://picsum.photos/seed/japanese/200/200';
  UPDATE cuisines SET icon = '/assets/cuisines/ukrainian.jpg' WHERE icon = 'https://picsum.photos/seed/ukrainian/200/200';
  UPDATE cuisines SET icon = '/assets/cuisines/thai.jpg' WHERE icon = 'https://picsum.photos/seed/thai/200/200';
  UPDATE cuisines SET icon = '/assets/cuisines/chinese.jpg' WHERE icon = 'https://picsum.photos/seed/chinese/200/200';
  UPDATE cuisines SET icon = '/assets/cuisines/korean.jpg' WHERE icon = 'https://picsum.photos/seed/korean/200/200';
  UPDATE restaurants SET logo = '/assets/restaurants/bh_logo.jpg' WHERE logo = 'https://picsum.photos/seed/bh_logo/100/100';
  UPDATE restaurants SET image = '/assets/restaurants/burgerhouse.jpg' WHERE image = 'https://picsum.photos/seed/burgerhouse/600/300';
  UPDATE restaurants SET logo = '/assets/restaurants/pp_logo.jpg' WHERE logo = 'https://picsum.photos/seed/pp_logo/100/100';
  UPDATE restaurants SET image = '/assets/restaurants/pizzapalace.jpg' WHERE image = 'https://picsum.photos/seed/pizzapalace/600/300';
  UPDATE restaurants SET logo = '/assets/restaurants/sw_logo.jpg' WHERE logo = 'https://picsum.photos/seed/sw_logo/100/100';
  UPDATE restaurants SET image = '/assets/restaurants/sushiworld.jpg' WHERE image = 'https://picsum.photos/seed/sushiworld/600/300';
  UPDATE restaurants SET logo = '/assets/restaurants/gm_logo.jpg' WHERE logo = 'https://picsum.photos/seed/gm_logo/100/100';
  UPDATE restaurants SET image = '/assets/restaurants/grillmaster.jpg' WHERE image = 'https://picsum.photos/seed/grillmaster/600/300';
  UPDATE restaurants SET logo = '/assets/restaurants/np_logo.jpg' WHERE logo = 'https://picsum.photos/seed/np_logo/100/100';
  UPDATE restaurants SET image = '/assets/restaurants/napolipizzeria.jpg' WHERE image = 'https://picsum.photos/seed/napolipizzeria/600/300';
  UPDATE restaurants SET logo = '/assets/restaurants/tsb_logo.jpg' WHERE logo = 'https://picsum.photos/seed/tsb_logo/100/100';
  UPDATE restaurants SET image = '/assets/restaurants/tokyosushibar.jpg' WHERE image = 'https://picsum.photos/seed/tokyosushibar/600/300';
  UPDATE restaurants SET logo = '/assets/restaurants/cs_logo.jpg' WHERE logo = 'https://picsum.photos/seed/cs_logo/100/100';
  UPDATE restaurants SET image = '/assets/restaurants/cheesyslice.jpg' WHERE image = 'https://picsum.photos/seed/cheesyslice/600/300';
  UPDATE products SET image = '/assets/products/classic_burger.jpg' WHERE image = 'https://picsum.photos/seed/classic_burger/300/300';
  UPDATE products SET image = '/assets/products/double_burger.jpg' WHERE image = 'https://picsum.photos/seed/double_burger/300/300';
  UPDATE products SET image = '/assets/products/fries.jpg' WHERE image = 'https://picsum.photos/seed/fries/300/300';
  UPDATE products SET image = '/assets/products/margherita.jpg' WHERE image = 'https://picsum.photos/seed/margherita/300/300';
  UPDATE products SET image = '/assets/products/pepperoni.jpg' WHERE image = 'https://picsum.photos/seed/pepperoni/300/300';
  UPDATE products SET image = '/assets/products/caesar.jpg' WHERE image = 'https://picsum.photos/seed/caesar/300/300';
  UPDATE products SET image = '/assets/products/salmon_roll.jpg' WHERE image = 'https://picsum.photos/seed/salmon_roll/300/300';
  UPDATE products SET image = '/assets/products/dragon_roll.jpg' WHERE image = 'https://picsum.photos/seed/dragon_roll/300/300';
  UPDATE products SET image = '/assets/products/miso.jpg' WHERE image = 'https://picsum.photos/seed/miso/300/300';
  UPDATE products SET image = '/assets/products/ribeye_burger.jpg' WHERE image = 'https://picsum.photos/seed/ribeye_burger/300/300';
  UPDATE products SET image = '/assets/products/bbq_burger.jpg' WHERE image = 'https://picsum.photos/seed/bbq_burger/300/300';
  UPDATE products SET image = '/assets/products/onion_rings.jpg' WHERE image = 'https://picsum.photos/seed/onion_rings/300/300';
  UPDATE products SET image = '/assets/products/quattro_formaggi.jpg' WHERE image = 'https://picsum.photos/seed/quattro_formaggi/300/300';
  UPDATE products SET image = '/assets/products/diavola.jpg' WHERE image = 'https://picsum.photos/seed/diavola/300/300';
  UPDATE products SET image = '/assets/products/garlic_bread.jpg' WHERE image = 'https://picsum.photos/seed/garlic_bread/300/300';
END
$$;
