import 'package:yumyum_backend/db/database_service.dart';
import 'package:yumyum_backend/models/refresh_token_record.dart';
import 'package:yumyum_backend/repositories/refresh_token_repository.dart';
import 'package:postgres/postgres.dart';

const _columns = '''
  id, user_id, family_id, issued_at, expires_at, revoked_at, replaced_by
''';

/// PostgreSQL-backed [RefreshTokenRepository].
class PostgresRefreshTokenRepository implements RefreshTokenRepository {
  /// Constructs a [PostgresRefreshTokenRepository] over the given [database].
  const PostgresRefreshTokenRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<void> issue(RefreshTokenRecord record) async {
    final db = await database.connection;
    await db.execute(
      Sql.named('''
        INSERT INTO refresh_tokens
          (id, user_id, family_id, issued_at, expires_at, revoked_at,
           replaced_by)
        VALUES
          (@id, @user_id, @family_id, @issued_at, @expires_at, NULL, NULL)
      '''),
      parameters: {
        'id': record.id,
        'user_id': record.userId,
        'family_id': record.familyId,
        'issued_at': record.issuedAt,
        'expires_at': record.expiresAt,
      },
    );
  }

  @override
  Future<RefreshTokenRecord?> findById(String id) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('SELECT $_columns FROM refresh_tokens WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return RefreshTokenRecord.fromRow(result.first.toColumnMap());
  }

  @override
  Future<void> revoke(
    String id, {
    required DateTime revokedAt,
    String? replacedBy,
  }) async {
    final db = await database.connection;
    // `revoked_at IS NULL` keeps the first revocation's timestamp rather than
    // letting a later call move it forward.
    await db.execute(
      Sql.named('''
        UPDATE refresh_tokens
        SET revoked_at = @revoked_at, replaced_by = @replaced_by
        WHERE id = @id AND revoked_at IS NULL
      '''),
      parameters: {
        'id': id,
        'revoked_at': revokedAt,
        'replaced_by': replacedBy,
      },
    );
  }

  @override
  Future<void> revokeFamily(
    String familyId, {
    required DateTime revokedAt,
  }) async {
    final db = await database.connection;
    await db.execute(
      Sql.named('''
        UPDATE refresh_tokens
        SET revoked_at = @revoked_at
        WHERE family_id = @family_id AND revoked_at IS NULL
      '''),
      parameters: {'family_id': familyId, 'revoked_at': revokedAt},
    );
  }

  @override
  Future<void> revokeAllForUser(
    String userId, {
    required DateTime revokedAt,
  }) async {
    final conn = await database.connection;
    await conn.execute(
      Sql.named('''
        UPDATE refresh_tokens
        SET revoked_at = @revoked_at
        WHERE user_id = @user_id AND revoked_at IS NULL
      '''),
      parameters: {'user_id': userId, 'revoked_at': revokedAt},
    );
  }

  @override
  Future<int> deleteExpired(DateTime now) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('DELETE FROM refresh_tokens WHERE expires_at < @now'),
      parameters: {'now': now},
    );
    return result.affectedRows;
  }

  @override
  Future<void> revokeAllRefreshTokensForUser(
    String uid, {
    required DateTime revokedAt,
  }) async {
    final db = await database.connection;
    await db.execute(
      Sql.named('''
        UPDATE refresh_tokens
        SET revoked_at = @revoked_at
        WHERE user_id = @user_id AND revoked_at IS NULL
      '''),
      parameters: {'user_id': uid, 'revoked_at': revokedAt},
    );
  }
}
