-- Demo catalog: categories, cuisines, restaurants and products for local
-- development, CI and integration tests.
--
-- Not a migration: production data is managed separately. Applied by
-- `dart run bin/migrate.dart --seed`; every insert is idempotent
-- (ON CONFLICT DO NOTHING), so re-running it is safe.

-- Food categories: the only kind of category. A product belongs to one; a
-- restaurant's categories are those of its products. "All" is the search
-- screen's catch-all chip and has no products of its own.
INSERT INTO categories (id, title_en, title_ru, title_uz, icon) VALUES
  (0, 'All', 'Все', 'Barchasi', '/assets/categories/all.svg'),
  (1, 'Burgers', 'Бургеры', 'Burgerlar', '/assets/categories/burger.svg'),
  (2, 'Pizza', 'Пицца', 'Pizza', '/assets/categories/pizza.svg'),
  (3, 'Sushi', 'Суши', 'Sushi', '/assets/categories/sushi.svg'),
  (4, 'Salads', 'Салаты', 'Salatlar', '/assets/categories/salad.svg'),
  (5, 'Pasta', 'Паста', 'Pasta', '/assets/categories/spaghetti.svg'),
  (6, 'Grill', 'Гриль', 'Grill', '/assets/categories/grill.svg'),
  (7, 'Dessert', 'Десерт', 'Shirinlik', '/assets/categories/cupcake.svg'),
  (8, 'Soups', 'Супы', 'Sho''rvalar', '/assets/categories/soup.svg'),
  (9, 'Sides', 'Закуски', 'Gazaklar', '/assets/categories/sides.svg')
ON CONFLICT (id) DO NOTHING;

INSERT INTO cuisines (id, title_en, title_ru, title_uz, icon) VALUES
  (0, 'All', 'Все', 'Barchasi', NULL),
  (1, 'American', 'Американская', 'Amerika oshxonasi', '/assets/cuisines/american.jpg'),
  (2, 'Italian', 'Итальянская', 'Italyan oshxonasi', '/assets/cuisines/italian.jpg'),
  (3, 'Japanese', 'Японская', 'Yapon oshxonasi', '/assets/cuisines/japanese.jpg'),
  (4, 'Ukrainian', 'Украинская', 'Ukrain oshxonasi', '/assets/cuisines/ukrainian.jpg'),
  (5, 'Thai', 'Тайская', 'Tay oshxonasi', '/assets/cuisines/thai.jpg'),
  (6, 'Chinese', 'Китайская', 'Xitoy oshxonasi', '/assets/cuisines/chinese.jpg'),
  (7, 'Korean', 'Корейская', 'Koreys oshxonasi', '/assets/cuisines/korean.jpg')
ON CONFLICT (id) DO NOTHING;

INSERT INTO restaurants (
  id, name, is_open, rating, logo, address, image, cuisine,
  start_time, end_time, description, phone_number, delivery_cost,
  min_delivery_time, max_delivery_time, free_delivery_from
) VALUES
  (
    1, 'Burger House', true, 4.5, '/assets/restaurants/bh_logo.jpg',
    '{"latitude":41.2995,"longitude":69.2401,"type":"other","street":"123 Amir Temur Ave","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    '/assets/restaurants/burgerhouse.jpg', 1, '09:00', '23:00',
    'Best smash burgers in town', '+998901234567', 5000.0, 20, 40, 50000.0
  ),
  (
    2, 'Pizza Palace', true, 4.2, '/assets/restaurants/pp_logo.jpg',
    '{"latitude":41.3111,"longitude":69.2797,"type":"other","street":"456 Navoi St","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    '/assets/restaurants/pizzapalace.jpg', 2, '10:00', '22:00',
    'Authentic Italian pizza baked in a wood oven', '+998907654321', 3000.0, 30, 50, 80000.0
  ),
  (
    3, 'Sushi World', false, 4.8, '/assets/restaurants/sw_logo.jpg',
    '{"latitude":41.2887,"longitude":69.2126,"type":"other","street":"789 Yunusabad Blvd","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    '/assets/restaurants/sushiworld.jpg', 3, '11:00', '21:00',
    'Premium Japanese cuisine made fresh daily', '+998909876543', 7000.0, 40, 60, 100000.0
  ),
  (
    4, 'Grill Master', true, 4.6, '/assets/restaurants/gm_logo.jpg',
    '{"latitude":41.3275,"longitude":69.2817,"type":"other","street":"12 Mustaqillik Ave","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    '/assets/restaurants/grillmaster.jpg', 1, '10:00', '23:00',
    'Flame-grilled burgers and steaks', '+998901112233', 4000.0, 25, 45, 60000.0
  ),
  (
    5, 'Napoli Pizzeria', true, 4.3, '/assets/restaurants/np_logo.jpg',
    '{"latitude":41.3054,"longitude":69.2437,"type":"other","street":"88 Buyuk Ipak Yoli","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    '/assets/restaurants/napolipizzeria.jpg', 2, '11:00', '23:00',
    'Wood-fired Neapolitan-style pizza', '+998904445566', 3500.0, 30, 55, 70000.0
  ),
  (
    6, 'Tokyo Sushi Bar', true, NULL, '/assets/restaurants/tsb_logo.jpg',
    '{"latitude":41.3167,"longitude":69.2500,"type":"other","street":"5 Shota Rustaveli St","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    '/assets/restaurants/tokyosushibar.jpg', 3, '11:00', '22:00',
    'Newly opened — menu coming soon', '+998907778899', 6000.0, 35, 60, 90000.0
  ),
  (
    7, 'Cheesy Slice', true, NULL, '/assets/restaurants/cs_logo.jpg',
    '{"latitude":41.2833,"longitude":69.2167,"type":"other","street":"200 Chilanzar St","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    '/assets/restaurants/cheesyslice.jpg', 2, '12:00', '22:00',
    'Newly opened — menu coming soon', '+998901239876', 4500.0, 25, 50, 60000.0
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO products (
  id, restaurant_id, category, price, status, title_en, title_ru, title_uz, image, description, unit
) VALUES
  (1, 1, 1, 25000.0, 'available', 'Classic Burger', 'Классический бургер', 'Klassik burger', '/assets/products/classic_burger.jpg', 'Beef patty with lettuce, tomato, and cheese', '250g'),
  (2, 1, 1, 35000.0, 'available', 'Double Smash Burger', 'Двойной смэш бургер', 'Ikki qatlamli burger', '/assets/products/double_burger.jpg', 'Two smashed beef patties with special sauce', '350g'),
  (3, 1, 9, 12000.0, 'available', 'Crispy Fries', 'Хрустящая картошка', 'Qovurilgan kartoshka', '/assets/products/fries.jpg', 'Golden crispy french fries', '150g'),
  (4, 2, 2, 45000.0, 'available', 'Margherita Pizza', 'Пицца Маргарита', 'Margarita pizza', '/assets/products/margherita.jpg', 'Classic tomato sauce with fresh mozzarella', '500g'),
  (5, 2, 2, 55000.0, 'available', 'Pepperoni Pizza', 'Пицца Пепперони', 'Pepperoni pizza', '/assets/products/pepperoni.jpg', 'Loaded with spicy pepperoni slices', '550g'),
  (6, 2, 4, 15000.0, 'available', 'Caesar Salad', 'Салат Цезарь', 'Sezar salati', '/assets/products/caesar.jpg', 'Romaine lettuce with caesar dressing and croutons', '200g'),
  (7, 3, 3, 35000.0, 'available', 'Salmon Roll', 'Ролл с лососем', 'Salmon roll', '/assets/products/salmon_roll.jpg', 'Fresh salmon with cucumber and avocado', '300g'),
  (8, 3, 3, 40000.0, 'available', 'Dragon Roll', 'Ролл Дракон', 'Dragon roll', '/assets/products/dragon_roll.jpg', 'Shrimp tempura topped with avocado', '320g'),
  (9, 3, 8, 28000.0, 'available', 'Miso Soup', 'Мисо суп', 'Miso sho''rva', '/assets/products/miso.jpg', 'Traditional Japanese miso soup with tofu', '350ml'),
  (10, 4, 1, 30000.0, 'available', 'Ribeye Burger', 'Бургер Рибай', 'Ribay burger', '/assets/products/ribeye_burger.jpg', 'Grilled ribeye patty with smoked cheddar', '300g'),
  (11, 4, 1, 22000.0, 'available', 'BBQ Bacon Burger', 'Бургер БАРБЕКЮ с беконом', 'BBQ bekonli burger', '/assets/products/bbq_burger.jpg', 'Beef patty with bacon and barbecue sauce', '280g'),
  (12, 4, 9, 14000.0, 'available', 'Onion Rings', 'Луковые кольца', 'Piyoz halqalari', '/assets/products/onion_rings.jpg', 'Crispy battered onion rings', '150g'),
  (13, 5, 2, 48000.0, 'available', 'Quattro Formaggi', 'Кватро Формаджи', 'Quattro Formaggi', '/assets/products/quattro_formaggi.jpg', 'Four-cheese pizza with a crispy crust', '500g'),
  (14, 5, 2, 52000.0, 'available', 'Diavola Pizza', 'Пицца Дьявола', 'Diavola pizza', '/assets/products/diavola.jpg', 'Spicy salami with chili-infused oil', '520g'),
  (15, 5, 9, 18000.0, 'available', 'Garlic Bread', 'Чесночный хлеб', 'Sarimsoqli non', '/assets/products/garlic_bread.jpg', 'Toasted baguette with garlic butter', '200g')
ON CONFLICT (id) DO NOTHING;
