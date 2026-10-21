-- Demo catalog: categories, cuisines, restaurant categories, restaurants and
-- products for local development, CI and integration tests.
--
-- Not a migration: production data is managed separately. Applied by
-- `dart run bin/migrate.dart --seed`; every insert is idempotent
-- (ON CONFLICT DO NOTHING), so re-running it is safe.

INSERT INTO categories (id, title_en, title_ru, title_uz, icon) VALUES
  (0, 'All', 'Все', 'Barchasi', NULL),
  (1, 'First course', 'Первое', 'Birinchi taom', 'https://picsum.photos/seed/first_course/200/200'),
  (2, 'Second course', 'Второе', 'Ikkinchi taom', 'https://picsum.photos/seed/second_course/200/200'),
  (3, 'Dessert', 'Десерт', 'Shirinlik', 'https://delmer-backend.fly.dev/assets/categories/cupcake.svg')
ON CONFLICT (id) DO NOTHING;

INSERT INTO cuisines (id, title_en, title_ru, title_uz, icon) VALUES
  (0, 'All', 'Все', 'Barchasi', NULL),
  (1, 'American', 'Американская', 'Amerika oshxonasi', 'https://picsum.photos/seed/american/200/200'),
  (2, 'Italian', 'Итальянская', 'Italyan oshxonasi', 'https://picsum.photos/seed/italian/200/200'),
  (3, 'Japanese', 'Японская', 'Yapon oshxonasi', 'https://picsum.photos/seed/japanese/200/200'),
  (4, 'Ukrainian', 'Украинская', 'Ukrain oshxonasi', 'https://picsum.photos/seed/ukrainian/200/200'),
  (5, 'Thai', 'Тайская', 'Tay oshxonasi', 'https://picsum.photos/seed/thai/200/200'),
  (6, 'Chinese', 'Китайская', 'Xitoy oshxonasi', 'https://picsum.photos/seed/chinese/200/200'),
  (7, 'Korean', 'Корейская', 'Koreys oshxonasi', 'https://picsum.photos/seed/korean/200/200')
ON CONFLICT (id) DO NOTHING;

INSERT INTO restaurant_categories (id, title_en, title_ru, title_uz, icon) VALUES
  (0, 'All', 'Все', 'Barchasi', 'https://delmer-backend.fly.dev/assets/categories/all-plate.svg'),
  (1, 'Burgers', 'Бургеры', 'Burgerlar', 'https://delmer-backend.fly.dev/assets/categories/burger.svg'),
  (2, 'Pizza', 'Пицца', 'Pizza', 'https://delmer-backend.fly.dev/assets/categories/pizza.svg'),
  (3, 'Sushi', 'Суши', 'Sushi', 'https://picsum.photos/seed/sushi/200/200'),
  (4, 'Salads', 'Салаты', 'Salatlar', 'https://delmer-backend.fly.dev/assets/categories/salad.svg'),
  (5, 'Pasta', 'Паста', 'Pasta', 'https://delmer-backend.fly.dev/assets/categories/spaghetti.svg'),
  (6, 'Grill', 'Гриль', 'Grill', 'https://picsum.photos/seed/grill/200/200')
ON CONFLICT (id) DO NOTHING;

INSERT INTO restaurants (
  id, name, is_open, rating, logo, address, image, cuisine, category,
  start_time, end_time, description, phone_number, delivery_cost,
  min_delivery_time, max_delivery_time, free_delivery_from, product_categories
) VALUES
  (
    1, 'Burger House', true, 4.5, 'https://picsum.photos/seed/bh_logo/100/100',
    '{"latitude":41.2995,"longitude":69.2401,"type":"other","street":"123 Amir Temur Ave","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/burgerhouse/600/300', 1, 1, '09:00', '23:00',
    'Best smash burgers in town', '+998901234567', 5000.0, 20, 40, 50000.0, '[2]'
  ),
  (
    2, 'Pizza Palace', true, 4.2, 'https://picsum.photos/seed/pp_logo/100/100',
    '{"latitude":41.3111,"longitude":69.2797,"type":"other","street":"456 Navoi St","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/pizzapalace/600/300', 2, 2, '10:00', '22:00',
    'Authentic Italian pizza baked in a wood oven', '+998907654321', 3000.0, 30, 50, 80000.0, '[2]'
  ),
  (
    3, 'Sushi World', false, 4.8, 'https://picsum.photos/seed/sw_logo/100/100',
    '{"latitude":41.2887,"longitude":69.2126,"type":"other","street":"789 Yunusabad Blvd","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/sushiworld/600/300', 3, 3, '11:00', '21:00',
    'Premium Japanese cuisine made fresh daily', '+998909876543', 7000.0, 40, 60, 100000.0, '[1, 2]'
  ),
  (
    4, 'Grill Master', true, 4.6, 'https://picsum.photos/seed/gm_logo/100/100',
    '{"latitude":41.3275,"longitude":69.2817,"type":"other","street":"12 Mustaqillik Ave","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/grillmaster/600/300', 1, 6, '10:00', '23:00',
    'Flame-grilled burgers and steaks', '+998901112233', 4000.0, 25, 45, 60000.0, '[2]'
  ),
  (
    5, 'Napoli Pizzeria', true, 4.3, 'https://picsum.photos/seed/np_logo/100/100',
    '{"latitude":41.3054,"longitude":69.2437,"type":"other","street":"88 Buyuk Ipak Yoli","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/napolipizzeria/600/300', 2, 2, '11:00', '23:00',
    'Wood-fired Neapolitan-style pizza', '+998904445566', 3500.0, 30, 55, 70000.0, '[2]'
  ),
  (
    6, 'Tokyo Sushi Bar', true, NULL, 'https://picsum.photos/seed/tsb_logo/100/100',
    '{"latitude":41.3167,"longitude":69.2500,"type":"other","street":"5 Shota Rustaveli St","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/tokyosushibar/600/300', 3, 3, '11:00', '22:00',
    'Newly opened — menu coming soon', '+998907778899', 6000.0, 35, 60, 90000.0, '[]'
  ),
  (
    7, 'Cheesy Slice', true, NULL, 'https://picsum.photos/seed/cs_logo/100/100',
    '{"latitude":41.2833,"longitude":69.2167,"type":"other","street":"200 Chilanzar St","city":"Tashkent","country":"Uzbekistan","isDefault":false}',
    'https://picsum.photos/seed/cheesyslice/600/300', 2, 2, '12:00', '22:00',
    'Newly opened — menu coming soon', '+998901239876', 4500.0, 25, 50, 60000.0, '[]'
  )
ON CONFLICT (id) DO NOTHING;

INSERT INTO products (
  id, restaurant_id, category, price, status, title_en, title_ru, title_uz, image, description, unit
) VALUES
  (1, 1, 2, 25000.0, 'available', 'Classic Burger', 'Классический бургер', 'Klassik burger', 'https://picsum.photos/seed/classic_burger/300/300', 'Beef patty with lettuce, tomato, and cheese', '250g'),
  (2, 1, 2, 35000.0, 'available', 'Double Smash Burger', 'Двойной смэш бургер', 'Ikki qatlamli burger', 'https://picsum.photos/seed/double_burger/300/300', 'Two smashed beef patties with special sauce', '350g'),
  (3, 1, 2, 12000.0, 'available', 'Crispy Fries', 'Хрустящая картошка', 'Qovurilgan kartoshka', 'https://picsum.photos/seed/fries/300/300', 'Golden crispy french fries', '150g'),
  (4, 2, 2, 45000.0, 'available', 'Margherita Pizza', 'Пицца Маргарита', 'Margarita pizza', 'https://picsum.photos/seed/margherita/300/300', 'Classic tomato sauce with fresh mozzarella', '500g'),
  (5, 2, 2, 55000.0, 'available', 'Pepperoni Pizza', 'Пицца Пепперони', 'Pepperoni pizza', 'https://picsum.photos/seed/pepperoni/300/300', 'Loaded with spicy pepperoni slices', '550g'),
  (6, 2, 2, 15000.0, 'available', 'Caesar Salad', 'Салат Цезарь', 'Sezar salati', 'https://picsum.photos/seed/caesar/300/300', 'Romaine lettuce with caesar dressing and croutons', '200g'),
  (7, 3, 2, 35000.0, 'available', 'Salmon Roll', 'Ролл с лососем', 'Salmon roll', 'https://picsum.photos/seed/salmon_roll/300/300', 'Fresh salmon with cucumber and avocado', '300g'),
  (8, 3, 2, 40000.0, 'available', 'Dragon Roll', 'Ролл Дракон', 'Dragon roll', 'https://picsum.photos/seed/dragon_roll/300/300', 'Shrimp tempura topped with avocado', '320g'),
  (9, 3, 1, 28000.0, 'available', 'Miso Soup', 'Мисо суп', 'Miso sho''rva', 'https://picsum.photos/seed/miso/300/300', 'Traditional Japanese miso soup with tofu', '350ml'),
  (10, 4, 2, 30000.0, 'available', 'Ribeye Burger', 'Бургер Рибай', 'Ribay burger', 'https://picsum.photos/seed/ribeye_burger/300/300', 'Grilled ribeye patty with smoked cheddar', '300g'),
  (11, 4, 2, 22000.0, 'available', 'BBQ Bacon Burger', 'Бургер БАРБЕКЮ с беконом', 'BBQ bekonli burger', 'https://picsum.photos/seed/bbq_burger/300/300', 'Beef patty with bacon and barbecue sauce', '280g'),
  (12, 4, 2, 14000.0, 'available', 'Onion Rings', 'Луковые кольца', 'Piyoz halqalari', 'https://picsum.photos/seed/onion_rings/300/300', 'Crispy battered onion rings', '150g'),
  (13, 5, 2, 48000.0, 'available', 'Quattro Formaggi', 'Кватро Формаджи', 'Quattro Formaggi', 'https://picsum.photos/seed/quattro_formaggi/300/300', 'Four-cheese pizza with a crispy crust', '500g'),
  (14, 5, 2, 52000.0, 'available', 'Diavola Pizza', 'Пицца Дьявола', 'Diavola pizza', 'https://picsum.photos/seed/diavola/300/300', 'Spicy salami with chili-infused oil', '520g'),
  (15, 5, 2, 18000.0, 'available', 'Garlic Bread', 'Чесночный хлеб', 'Sarimsoqli non', 'https://picsum.photos/seed/garlic_bread/300/300', 'Toasted baguette with garlic butter', '200g')
ON CONFLICT (id) DO NOTHING;
