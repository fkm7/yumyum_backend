import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/models/password_reset_token.dart';
import 'package:yumyum_backend/repositories/password_reset_token_repository.dart';
import 'package:postgres/postgres.dart';

const _columns = 'id, user_id, token_hash, expires_at, used_at';

/// PostgreSQL-backed [PasswordResetTokenRepository].
class PostgresPasswordResetTokenRepository
    implements PasswordResetTokenRepository {
  /// Constructs a [PostgresPasswordResetTokenRepository] over the given
  /// [database].
  const PostgresPasswordResetTokenRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<void> issue(PasswordResetToken token) async {
    final conn = await database.connection;
    await conn.execute(
      Sql.named('''
        INSERT INTO password_reset_tokens
          (id, user_id, token_hash, expires_at, used_at, created_at)
        VALUES
          (@id, @user_id, @token_hash, @expires_at, NULL, @created_at)
      '''),
      parameters: {
        'id': token.id,
        'user_id': token.userId,
        'token_hash': token.tokenHash,
        'expires_at': token.expiresAt,
        'created_at': DateTime.now().toUtc(),
      },
    );
  }

  @override
  Future<PasswordResetToken?> findByTokenHash(String tokenHash) async {
    final conn = await database.connection;
    final result = await conn.execute(
      Sql.named(
        'SELECT $_columns FROM password_reset_tokens '
        'WHERE token_hash = @token_hash',
      ),
      parameters: {'token_hash': tokenHash},
    );
    if (result.isEmpty) return null;
    return PasswordResetToken.fromRow(result.first.toColumnMap());
  }

  @override
  Future<void> markUsed(String id, {required DateTime usedAt}) async {
    final conn = await database.connection;
    await conn.execute(
      Sql.named(
        'UPDATE password_reset_tokens SET used_at = @used_at '
        'WHERE id = @id AND used_at IS NULL',
      ),
      parameters: {'id': id, 'used_at': usedAt},
    );
  }

  @override
  Future<void> deleteUnusedForUser(String userId) async {
    final conn = await database.connection;
    await conn.execute(
      Sql.named(
        'DELETE FROM password_reset_tokens '
        'WHERE user_id = @user_id AND used_at IS NULL',
      ),
      parameters: {'user_id': userId},
    );
  }
}
