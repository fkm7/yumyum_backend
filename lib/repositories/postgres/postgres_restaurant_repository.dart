import 'package:yumyum_backend/db/database_service.dart';
import 'package:yumyum_backend/models/restaurant.dart';
import 'package:yumyum_backend/repositories/restaurant_repository.dart';
import 'package:postgres/postgres.dart';

// product_categories stores a JSONB array of category ids (e.g. `[1, 2]`);
// this expands it into the matching `categories` rows as a JSONB array of
// objects, so Restaurant.fromRow can decode it the same way it decodes the
// joined cuisine/category columns. NULL is preserved as NULL (no menu
// categories recorded yet) rather than collapsing it into an empty array.
const _productCategories = '''
  CASE WHEN r.product_categories IS NULL THEN NULL ELSE COALESCE(
    (
      SELECT jsonb_agg(
               jsonb_build_object(
                 'id', pc.id, 'title_en', pc.title_en,
                 'title_ru', pc.title_ru, 'title_uz', pc.title_uz,
                 'icon', pc.icon
               ) ORDER BY pc.id
             )
      FROM categories pc
      WHERE pc.id IN (
        SELECT jsonb_array_elements_text(r.product_categories)::int
      )
    ),
    '[]'::jsonb
  ) END AS product_categories
''';

const _columns = '''
  r.id, r.name, r.is_open, r.rating, r.logo, r.address, r.image,
  r.start_time, r.end_time, r.description, r.phone_number, r.delivery_cost,
  r.min_delivery_time, r.max_delivery_time, r.free_delivery_from,
  $_productCategories,
  cu.id AS cuisine_id, cu.title_en AS cuisine_title_en,
  cu.title_ru AS cuisine_title_ru, cu.title_uz AS cuisine_title_uz,
  cu.icon AS cuisine_icon,
  rc.id AS category_id, rc.title_en AS category_title_en,
  rc.title_ru AS category_title_ru, rc.title_uz AS category_title_uz,
  rc.icon AS category_icon
''';

const _from = '''
  restaurants r
  JOIN cuisines cu ON cu.id = r.cuisine
  JOIN restaurant_categories rc ON rc.id = r.category
''';

/// PostgreSQL-backed [RestaurantRepository].
class PostgresRestaurantRepository implements RestaurantRepository {
  /// Constructs a [PostgresRestaurantRepository] over the given [database].
  const PostgresRestaurantRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<Restaurant>> findAll() async {
    final db = await database.connection;
    final result = await db.execute(
      'SELECT $_columns FROM $_from ORDER BY r.id',
    );
    return _map(result);
  }

  @override
  Future<List<Restaurant>> findByCuisine(int cuisineId) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named(
        'SELECT $_columns FROM $_from WHERE r.cuisine = @cuisine '
        'ORDER BY r.id',
      ),
      parameters: {'cuisine': cuisineId},
    );
    return _map(result);
  }

  @override
  Future<List<Restaurant>> findByCategory(int categoryId) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named(
        'SELECT $_columns FROM $_from WHERE r.category = @category '
        'ORDER BY r.id',
      ),
      parameters: {'category': categoryId},
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
