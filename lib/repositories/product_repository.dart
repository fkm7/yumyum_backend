import 'package:yumyum_backend/models/product.dart';

/// Read access to the `products` table.
abstract class ProductRepository {
  /// Returns every product, ordered by id.
  Future<List<Product>> findAll();

  /// Returns the product with the given id, or null when absent.
  Future<Product?> findById(int id);

  /// Returns the products belonging to the given restaurant, ordered by id.
  Future<List<Product>> findByRestaurant(int restaurantId);

  /// Returns the products matching the given ids, in an unspecified order.
  ///
  /// Ids that do not exist are simply absent from the result; it is the
  /// caller's job to decide whether that is an error.
  Future<List<Product>> findByIds(List<int> ids);
}
