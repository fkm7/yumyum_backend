import 'package:yumyum_backend/models/restaurant_category.dart';

/// Read access to the `restaurant_categories` table.
// ignore: one_member_abstracts
abstract class RestaurantCategoryRepository {
  /// Returns every restaurant category, ordered by id.
  Future<List<RestaurantCategory>> findAll();
}
