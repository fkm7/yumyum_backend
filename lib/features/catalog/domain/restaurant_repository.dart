import 'package:yumyum_backend/features/catalog/domain/restaurant.dart';

/// Read access to the `restaurants` table.
abstract class RestaurantRepository {
  /// Returns restaurants ordered by id, optionally narrowed down.
  ///
  /// [cuisineId] keeps restaurants serving that cuisine. [categoryId] keeps
  /// restaurants with at least one product in that category — what the
  /// search screen shows when a category is tapped. Both together must both
  /// match; neither returns every restaurant.
  Future<List<Restaurant>> findAll({int? cuisineId, int? categoryId});

  /// Returns the restaurant with the given id, or null when absent.
  Future<Restaurant?> findById(int id);

  /// Returns the restaurants matching the given ids, in an unspecified order.
  ///
  /// Ids that do not exist are simply absent from the result; it is the
  /// caller's job to decide whether that is an error.
  Future<List<Restaurant>> findByIds(List<int> ids);
}
