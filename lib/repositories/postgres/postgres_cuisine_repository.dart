import 'package:delmer_backend/db/database_service.dart';
import 'package:delmer_backend/models/cuisine.dart';
import 'package:delmer_backend/repositories/cuisine_repository.dart';

/// PostgreSQL-backed [CuisineRepository].
class PostgresCuisineRepository implements CuisineRepository {
  /// Constructs a [PostgresCuisineRepository] over the given [database].
  const PostgresCuisineRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<Cuisine>> findAll() async {
    final conn = await database.connection;
    final result = await conn.execute(
      'SELECT id, title_en, title_ru, title_uz, icon FROM cuisines '
      'ORDER BY id',
    );
    return result.map((row) => Cuisine.fromRow(row.toColumnMap())).toList();
  }
}
