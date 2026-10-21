-- Points catalog icons at the SVGs shipped in `public/assets/categories/`,
-- which the server serves as static files.
--
-- Rows are matched by `title_en` rather than `id`: production catalog data is
-- managed separately from the demo seed, so ids are not guaranteed to line up.
-- A database without these rows (a fresh one, before seeding) is left as is;
-- `db/seeds/demo_catalog.sql` inserts the same URLs.

UPDATE restaurant_categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/all-plate.svg' WHERE title_en = 'All';
UPDATE restaurant_categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/burger.svg' WHERE title_en = 'Burgers';
UPDATE restaurant_categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/pizza.svg' WHERE title_en = 'Pizza';
UPDATE restaurant_categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/salad.svg' WHERE title_en = 'Salads';
UPDATE restaurant_categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/spaghetti.svg' WHERE title_en = 'Pasta';

UPDATE categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/cupcake.svg' WHERE title_en = 'Dessert';
