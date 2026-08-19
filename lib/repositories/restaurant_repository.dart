import 'package:delmer_backend/models/restaurant.dart';

/// Read access to the `restaurants` table.
abstract class RestaurantRepository {
  /// Returns every restaurant, ordered by id.
  Future<List<Restaurant>> findAll();

  /// Returns the restaurants serving the given cuisine, ordered by id.
  Future<List<Restaurant>> findByCuisine(int cuisineId);

  /// Returns the restaurant with the given id, or null when absent.
  Future<Restaurant?> findById(int id);

  /// Returns the restaurants matching the given ids, in an unspecified order.
  ///
  /// Ids that do not exist are simply absent from the result; it is the
  /// caller's job to decide whether that is an error.
  Future<List<Restaurant>> findByIds(List<int> ids);
}
