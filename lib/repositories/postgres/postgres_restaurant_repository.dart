import 'package:delmer_backend/db/database_service.dart';
import 'package:delmer_backend/models/restaurant.dart';
import 'package:delmer_backend/repositories/restaurant_repository.dart';
import 'package:postgres/postgres.dart';

const _columns = '''
  id, name, is_open, rating, logo, address, image, cuisine, category,
  start_time, end_time, description, phone_number, delivery_cost,
  min_delivery_time, max_delivery_time, free_delivery_from, product_categories
''';

/// PostgreSQL-backed [RestaurantRepository].
class PostgresRestaurantRepository implements RestaurantRepository {
  /// Constructs a [PostgresRestaurantRepository] over the given [database].
  const PostgresRestaurantRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<Restaurant>> findAll() async {
    final conn = await database.connection;
    final result = await conn.execute(
      'SELECT $_columns FROM restaurants ORDER BY id',
    );
    return _map(result);
  }

  @override
  Future<List<Restaurant>> findByCuisine(int cuisineId) async {
    final conn = await database.connection;
    final result = await conn.execute(
      Sql.named(
        'SELECT $_columns FROM restaurants WHERE cuisine = @cuisine '
        'ORDER BY id',
      ),
      parameters: {'cuisine': cuisineId},
    );
    return _map(result);
  }

  @override
  Future<List<Restaurant>> findByCategory(int categoryId) async {
    final conn = await database.connection;
    final result = await conn.execute(
      Sql.named(
        'SELECT $_columns FROM restaurants WHERE category = @category '
        'ORDER BY id',
      ),
      parameters: {'category': categoryId},
    );
    return _map(result);
  }

  @override
  Future<Restaurant?> findById(int id) async {
    final conn = await database.connection;
    final result = await conn.execute(
      Sql.named('SELECT $_columns FROM restaurants WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return Restaurant.fromRow(result.first.toColumnMap());
  }

  @override
  Future<List<Restaurant>> findByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final conn = await database.connection;
    final result = await conn.execute(
      Sql.named('SELECT $_columns FROM restaurants WHERE id = ANY(@ids)'),
      parameters: {'ids': TypedValue(Type.integerArray, ids)},
    );
    return _map(result);
  }

  List<Restaurant> _map(Result result) =>
      result.map((row) => Restaurant.fromRow(row.toColumnMap())).toList();
}
