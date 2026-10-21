-- Orders are kept as anonymised business records when the things they point
-- at are deleted, instead of blocking the delete.
--
-- Without this, deleting a user who has ever ordered fails with a foreign key
-- violation, and so does deleting a saved address or payment method an order
-- used — including the cascade from a user deletion. PostgresUserRepository
-- scrubs the delivery_address/payment_detail snapshots itself; these
-- constraints only detach the references.
--
-- Constraint names are PostgreSQL's defaults for the column-level REFERENCES
-- in 001 and 002.

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_user_id_fkey;
ALTER TABLE orders ADD CONSTRAINT orders_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(uid) ON DELETE SET NULL;

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_address_id_fkey;
ALTER TABLE orders ADD CONSTRAINT orders_address_id_fkey
  FOREIGN KEY (address_id) REFERENCES addresses(id) ON DELETE SET NULL;

ALTER TABLE orders DROP CONSTRAINT IF EXISTS orders_payment_method_id_fkey;
ALTER TABLE orders ADD CONSTRAINT orders_payment_method_id_fkey
  FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id)
  ON DELETE SET NULL;
