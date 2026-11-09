-- Replaces the picsum.photos placeholder images from the demo seed with
-- copies shipped in `public/assets/`, which the server serves as static files.
--
-- Each row is matched on its exact old URL, so only values that still hold
-- the original placeholder are touched; anything already changed is left as is.
-- `db/seeds/demo_catalog.sql` inserts the same new URLs on a fresh database.

UPDATE categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/first_course.jpg' WHERE icon = 'https://picsum.photos/seed/first_course/200/200';
UPDATE categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/second_course.jpg' WHERE icon = 'https://picsum.photos/seed/second_course/200/200';

UPDATE cuisines SET icon = 'https://delmer-backend.fly.dev/assets/cuisines/american.jpg' WHERE icon = 'https://picsum.photos/seed/american/200/200';
UPDATE cuisines SET icon = 'https://delmer-backend.fly.dev/assets/cuisines/italian.jpg' WHERE icon = 'https://picsum.photos/seed/italian/200/200';
UPDATE cuisines SET icon = 'https://delmer-backend.fly.dev/assets/cuisines/japanese.jpg' WHERE icon = 'https://picsum.photos/seed/japanese/200/200';
UPDATE cuisines SET icon = 'https://delmer-backend.fly.dev/assets/cuisines/ukrainian.jpg' WHERE icon = 'https://picsum.photos/seed/ukrainian/200/200';
UPDATE cuisines SET icon = 'https://delmer-backend.fly.dev/assets/cuisines/thai.jpg' WHERE icon = 'https://picsum.photos/seed/thai/200/200';
UPDATE cuisines SET icon = 'https://delmer-backend.fly.dev/assets/cuisines/chinese.jpg' WHERE icon = 'https://picsum.photos/seed/chinese/200/200';
UPDATE cuisines SET icon = 'https://delmer-backend.fly.dev/assets/cuisines/korean.jpg' WHERE icon = 'https://picsum.photos/seed/korean/200/200';

UPDATE restaurant_categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/sushi.jpg' WHERE icon = 'https://picsum.photos/seed/sushi/200/200';
UPDATE restaurant_categories SET icon = 'https://delmer-backend.fly.dev/assets/categories/grill.jpg' WHERE icon = 'https://picsum.photos/seed/grill/200/200';

UPDATE restaurants SET logo = 'https://delmer-backend.fly.dev/assets/restaurants/bh_logo.jpg' WHERE logo = 'https://picsum.photos/seed/bh_logo/100/100';
UPDATE restaurants SET image = 'https://delmer-backend.fly.dev/assets/restaurants/burgerhouse.jpg' WHERE image = 'https://picsum.photos/seed/burgerhouse/600/300';
UPDATE restaurants SET logo = 'https://delmer-backend.fly.dev/assets/restaurants/pp_logo.jpg' WHERE logo = 'https://picsum.photos/seed/pp_logo/100/100';
UPDATE restaurants SET image = 'https://delmer-backend.fly.dev/assets/restaurants/pizzapalace.jpg' WHERE image = 'https://picsum.photos/seed/pizzapalace/600/300';
UPDATE restaurants SET logo = 'https://delmer-backend.fly.dev/assets/restaurants/sw_logo.jpg' WHERE logo = 'https://picsum.photos/seed/sw_logo/100/100';
UPDATE restaurants SET image = 'https://delmer-backend.fly.dev/assets/restaurants/sushiworld.jpg' WHERE image = 'https://picsum.photos/seed/sushiworld/600/300';
UPDATE restaurants SET logo = 'https://delmer-backend.fly.dev/assets/restaurants/gm_logo.jpg' WHERE logo = 'https://picsum.photos/seed/gm_logo/100/100';
UPDATE restaurants SET image = 'https://delmer-backend.fly.dev/assets/restaurants/grillmaster.jpg' WHERE image = 'https://picsum.photos/seed/grillmaster/600/300';
UPDATE restaurants SET logo = 'https://delmer-backend.fly.dev/assets/restaurants/np_logo.jpg' WHERE logo = 'https://picsum.photos/seed/np_logo/100/100';
UPDATE restaurants SET image = 'https://delmer-backend.fly.dev/assets/restaurants/napolipizzeria.jpg' WHERE image = 'https://picsum.photos/seed/napolipizzeria/600/300';
UPDATE restaurants SET logo = 'https://delmer-backend.fly.dev/assets/restaurants/tsb_logo.jpg' WHERE logo = 'https://picsum.photos/seed/tsb_logo/100/100';
UPDATE restaurants SET image = 'https://delmer-backend.fly.dev/assets/restaurants/tokyosushibar.jpg' WHERE image = 'https://picsum.photos/seed/tokyosushibar/600/300';
UPDATE restaurants SET logo = 'https://delmer-backend.fly.dev/assets/restaurants/cs_logo.jpg' WHERE logo = 'https://picsum.photos/seed/cs_logo/100/100';
UPDATE restaurants SET image = 'https://delmer-backend.fly.dev/assets/restaurants/cheesyslice.jpg' WHERE image = 'https://picsum.photos/seed/cheesyslice/600/300';

UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/classic_burger.jpg' WHERE image = 'https://picsum.photos/seed/classic_burger/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/double_burger.jpg' WHERE image = 'https://picsum.photos/seed/double_burger/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/fries.jpg' WHERE image = 'https://picsum.photos/seed/fries/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/margherita.jpg' WHERE image = 'https://picsum.photos/seed/margherita/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/pepperoni.jpg' WHERE image = 'https://picsum.photos/seed/pepperoni/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/caesar.jpg' WHERE image = 'https://picsum.photos/seed/caesar/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/salmon_roll.jpg' WHERE image = 'https://picsum.photos/seed/salmon_roll/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/dragon_roll.jpg' WHERE image = 'https://picsum.photos/seed/dragon_roll/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/miso.jpg' WHERE image = 'https://picsum.photos/seed/miso/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/ribeye_burger.jpg' WHERE image = 'https://picsum.photos/seed/ribeye_burger/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/bbq_burger.jpg' WHERE image = 'https://picsum.photos/seed/bbq_burger/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/onion_rings.jpg' WHERE image = 'https://picsum.photos/seed/onion_rings/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/quattro_formaggi.jpg' WHERE image = 'https://picsum.photos/seed/quattro_formaggi/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/diavola.jpg' WHERE image = 'https://picsum.photos/seed/diavola/300/300';
UPDATE products SET image = 'https://delmer-backend.fly.dev/assets/products/garlic_bread.jpg' WHERE image = 'https://picsum.photos/seed/garlic_bread/300/300';
