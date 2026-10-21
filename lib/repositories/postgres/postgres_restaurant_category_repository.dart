import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/models/restaurant_category.dart';
import 'package:yumyum_backend/repositories/restaurant_category_repository.dart';

/// PostgreSQL-backed [RestaurantCategoryRepository].
class PostgresRestaurantCategoryRepository
    implements RestaurantCategoryRepository {
  /// Constructs a [PostgresRestaurantCategoryRepository] over the given
  /// [database].
  const PostgresRestaurantCategoryRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<RestaurantCategory>> findAll() async {
    final db = await database.connection;
    final result = await db.execute(
      'SELECT id, title_en, title_ru, title_uz, icon FROM '
      'restaurant_categories ORDER BY id',
    );
    return result
        .map((row) => RestaurantCategory.fromRow(row.toColumnMap()))
        .toList();
  }
}
