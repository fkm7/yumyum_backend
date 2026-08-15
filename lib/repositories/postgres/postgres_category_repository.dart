import 'package:delmer_backend/db/database_service.dart';
import 'package:delmer_backend/models/category.dart';
import 'package:delmer_backend/repositories/category_repository.dart';

/// PostgreSQL-backed [CategoryRepository].
class PostgresCategoryRepository implements CategoryRepository {
  /// Constructs a [PostgresCategoryRepository] over the given [database].
  const PostgresCategoryRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<Category>> findAll() async {
    final conn = await database.connection;
    final result = await conn.execute(
      'SELECT id, title_en, title_ru, title_uz, icon FROM categories '
      'ORDER BY id',
    );
    return result.map((row) => Category.fromRow(row.toColumnMap())).toList();
  }
}
