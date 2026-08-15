import 'package:delmer_backend/models/restaurant.dart';

/// Read access to the `restaurants` table.
abstract class RestaurantRepository {
  /// Returns every restaurant, ordered by id.
  Future<List<Restaurant>> findAll();

  /// Returns the restaurants in the given category, ordered by id.
  Future<List<Restaurant>> findByCategory(int categoryId);

  /// Returns the restaurant with the given id, or null when absent.
  Future<Restaurant?> findById(int id);
}
