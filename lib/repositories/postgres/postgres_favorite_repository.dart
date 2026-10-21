import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/repositories/favorite_repository.dart';
import 'package:postgres/postgres.dart';

/// PostgreSQL-backed [FavoriteRepository].
class PostgresFavoriteRepository implements FavoriteRepository {
  /// Constructs a [PostgresFavoriteRepository] over the given [database].
  const PostgresFavoriteRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<void> add(String userId, FavoriteType type, int itemId) async {
    final db = await database.connection;
    await db.execute(
      Sql.named('''
        INSERT INTO favorites (user_id, item_type, item_id, created_at)
        VALUES (@user_id, @item_type, @item_id, @created_at)
        ON CONFLICT (user_id, item_type, item_id) DO NOTHING
      '''),
      parameters: {
        'user_id': userId,
        'item_type': type.value,
        'item_id': itemId,
        'created_at': DateTime.now().toUtc(),
      },
    );
  }

  @override
  Future<void> remove(String userId, FavoriteType type, int itemId) async {
    final db = await database.connection;
    await db.execute(
      Sql.named('''
        DELETE FROM favorites
        WHERE user_id = @user_id AND item_type = @item_type
          AND item_id = @item_id
      '''),
      parameters: {
        'user_id': userId,
        'item_type': type.value,
        'item_id': itemId,
      },
    );
  }

  @override
  Future<List<int>> findIds(String userId, FavoriteType type) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('''
        SELECT item_id FROM favorites
        WHERE user_id = @user_id AND item_type = @item_type
        ORDER BY created_at DESC
      '''),
      parameters: {'user_id': userId, 'item_type': type.value},
    );
    return result.map((row) => row.toColumnMap()['item_id'] as int).toList();
  }
}
