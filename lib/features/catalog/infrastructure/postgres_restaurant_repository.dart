import 'package:postgres/postgres.dart';
import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant_repository.dart';

// A restaurant's menu sections are the distinct categories of its products,
// as a JSONB array of {id, restaurant_id, titles} objects ordered by category
// id (no icon), so Restaurant.fromRow decodes them like any other row. A
// restaurant with no products gets `[]`.
const _menuCategories = '''
  COALESCE(
    (
      SELECT jsonb_agg(
               jsonb_build_object(
                 'id', c.id, 'restaurant_id', r.id,
                 'title_en', c.title_en, 'title_ru', c.title_ru,
                 'title_uz', c.title_uz
               ) ORDER BY c.id
             )
      FROM categories c
      WHERE EXISTS (
        SELECT 1 FROM products p
        WHERE p.restaurant_id = r.id AND p.category = c.id
      )
    ),
    '[]'::jsonb
  ) AS menu_categories
''';

const _columns = '''
  r.id, r.name, r.is_open, r.rating, r.logo, r.address, r.image,
  r.start_time, r.end_time, r.description, r.phone_number, r.delivery_cost,
  r.min_delivery_time, r.max_delivery_time, r.free_delivery_from,
  $_menuCategories,
  cu.id AS cuisine_id, cu.title_en AS cuisine_title_en,
  cu.title_ru AS cuisine_title_ru, cu.title_uz AS cuisine_title_uz,
  cu.icon AS cuisine_icon
''';

const _from = '''
  restaurants r
  JOIN cuisines cu ON cu.id = r.cuisine
''';

// Restaurants with at least one product in the requested category.
const _servesCategory = 'EXISTS (SELECT 1 FROM products p '
    'WHERE p.restaurant_id = r.id AND p.category = @category)';

/// PostgreSQL-backed [RestaurantRepository].
class PostgresRestaurantRepository implements RestaurantRepository {
  /// Constructs a [PostgresRestaurantRepository] over the given [database].
  const PostgresRestaurantRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<Restaurant>> findAll({int? cuisineId, int? categoryId}) async {
    final conditions = [
      if (cuisineId != null) 'r.cuisine = @cuisine',
      if (categoryId != null) _servesCategory,
    ];
    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')} ';

    final db = await database.connection;
    final result = await db.execute(
      Sql.named('SELECT $_columns FROM $_from ${where}ORDER BY r.id'),
      parameters: {
        if (cuisineId != null) 'cuisine': cuisineId,
        if (categoryId != null) 'category': categoryId,
      },
    );
    return _map(result);
  }

  @override
  Future<Restaurant?> findById(int id) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('SELECT $_columns FROM $_from WHERE r.id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return Restaurant.fromRow(result.first.toColumnMap());
  }

  @override
  Future<List<Restaurant>> findByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('SELECT $_columns FROM $_from WHERE r.id = ANY(@ids)'),
      parameters: {'ids': TypedValue(Type.integerArray, ids)},
    );
    return _map(result);
  }

  List<Restaurant> _map(Result result) =>
      result.map((row) => Restaurant.fromRow(row.toColumnMap())).toList();
}
