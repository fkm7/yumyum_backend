import 'package:yumyum_backend/db/database_service.dart';
import 'package:yumyum_backend/models/product.dart';
import 'package:yumyum_backend/repositories/product_repository.dart';
import 'package:postgres/postgres.dart';

const _columns = '''
  p.id, p.restaurant_id, p.status, p.price, p.title_en, p.title_ru,
  p.title_uz, p.image, p.description, p.unit,
  c.id AS category_id, c.title_en AS category_title_en,
  c.title_ru AS category_title_ru, c.title_uz AS category_title_uz,
  c.icon AS category_icon
''';

const _from = 'products p JOIN categories c ON c.id = p.category';

/// PostgreSQL-backed [ProductRepository].
class PostgresProductRepository implements ProductRepository {
  /// Constructs a [PostgresProductRepository] over the given [database].
  const PostgresProductRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<Product>> findAll() async {
    final db = await database.connection;
    final result = await db.execute(
      'SELECT $_columns FROM $_from ORDER BY p.id',
    );
    return _map(result);
  }

  @override
  Future<Product?> findById(int id) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('SELECT $_columns FROM $_from WHERE p.id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return Product.fromRow(result.first.toColumnMap());
  }

  @override
  Future<List<Product>> findByRestaurant(int restaurantId) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named(
        'SELECT $_columns FROM $_from WHERE p.restaurant_id = @id '
        'ORDER BY p.id',
      ),
      parameters: {'id': restaurantId},
    );
    return _map(result);
  }

  @override
  Future<List<Product>> findByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database.connection;
    // ANY(@ids) keeps this a single round trip and a single prepared
    // statement regardless of cart size, instead of one SELECT per line.
    final result = await db.execute(
      Sql.named('SELECT $_columns FROM $_from WHERE p.id = ANY(@ids)'),
      parameters: {'ids': TypedValue(Type.integerArray, ids)},
    );
    return _map(result);
  }

  List<Product> _map(Result result) =>
      result.map((row) => Product.fromRow(row.toColumnMap())).toList();
}
