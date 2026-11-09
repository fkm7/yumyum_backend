import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/features/catalog/domain/product_category.dart';
import 'package:yumyum_backend/features/catalog/domain/product_category_repository.dart';

/// PostgreSQL-backed [CategoryRepository].
class PostgresCategoryRepository implements CategoryRepository {
  /// Constructs a [PostgresCategoryRepository] over the given [database].
  const PostgresCategoryRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<ProductCategory>> findAll() async {
    final db = await database.connection;
    final result = await db.execute(
      'SELECT id, title_en, title_ru, title_uz, icon FROM product_categories '
      'ORDER BY id',
    );
    return result
        .map((row) => ProductCategory.fromRow(row.toColumnMap()))
        .toList();
  }
}
