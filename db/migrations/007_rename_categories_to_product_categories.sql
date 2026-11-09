-- Renames `categories` to `product_categories`, so the table for a product's
-- course reads unambiguously next to `restaurant_categories`.
--
-- Foreign keys (`products.category`) follow the rename automatically. The
-- primary key index is renamed too, to keep it in line with the table name.

ALTER TABLE categories RENAME TO product_categories;
ALTER INDEX categories_pkey RENAME TO product_categories_pkey;
