import 'package:delmer_backend/db/database_service.dart';
import 'package:delmer_backend/models/product.dart';
import 'package:delmer_backend/repositories/product_repository.dart';
import 'package:postgres/postgres.dart';

const _columns = '''
  id, restaurant_id, category, status, price, title_en, title_ru, title_uz,
  image, description
''';

/// PostgreSQL-backed [ProductRepository].
class PostgresProductRepository implements ProductRepository {
  /// Constructs a [PostgresProductRepository] over the given [database].
  const PostgresProductRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<Product>> findAll() async {
    final conn = await database.connection;
    final result = await conn.execute(
      'SELECT $_columns FROM products ORDER BY id',
    );
    return _map(result);
  }

  @override
  Future<Product?> findById(int id) async {
    final conn = await database.connection;
    final result = await conn.execute(
      Sql.named('SELECT $_columns FROM products WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return Product.fromRow(result.first.toColumnMap());
  }

  @override
  Future<List<Product>> findByRestaurant(int restaurantId) async {
    final conn = await database.connection;
    final result = await conn.execute(
      Sql.named(
        'SELECT $_columns FROM products WHERE restaurant_id = @id ORDER BY id',
      ),
      parameters: {'id': restaurantId},
    );
    return _map(result);
  }

  @override
  Future<List<Product>> findByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final conn = await database.connection;
    // ANY(@ids) keeps this a single round trip and a single prepared
    // statement regardless of cart size, instead of one SELECT per line.
    final result = await conn.execute(
      Sql.named('SELECT $_columns FROM products WHERE id = ANY(@ids)'),
      parameters: {'ids': TypedValue(Type.integerArray, ids)},
    );
    return _map(result);
  }

  List<Product> _map(Result result) =>
      result.map((row) => Product.fromRow(row.toColumnMap())).toList();
}
