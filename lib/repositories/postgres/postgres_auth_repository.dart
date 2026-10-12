import 'package:yumyum_backend/db/database_service.dart';
import 'package:yumyum_backend/models/password_reset_record.dart';
import 'package:yumyum_backend/repositories/auth_repository.dart';
import 'package:uuid/uuid.dart';

/// A PostgreSQL implementation of the [AuthRepository].
class PostgresAuthRepository implements AuthRepository {
  /// Constructs a [PostgresAuthRepository] over the given [database].
  const PostgresAuthRepository(this.database, {Uuid uuid = const Uuid()})
      : _uuid = uuid;

  /// The database service used to interact with the PostgreSQL database.
  final DatabaseService database;
  final Uuid _uuid;

  @override
  Future<void> createPasswordResetRecord({
    required String userId,
    required String tokenHash,
    required DateTime expiresAt,
  }) async {
    final db = await database.connection;
    await db.execute(
      '''
      INSERT INTO password_reset_records (id, user_id, token_hash, expires_at)
      VALUES (@id, @userId, @tokenHash, @expiresAt)
      ''',
      parameters: {
        'id': _uuid.v4(),
        'userId': userId,
        'tokenHash': tokenHash,
        'expiresAt': expiresAt.toUtc(),
      },
    );
  }

  @override
  Future<void> createRefreshToken({
    required String userId,
    required String tokenHash,
    required DateTime expiresAt,
  }) async {
    final db = await database.connection;
    await db.execute(
      '''
      INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at)
      VALUES (@id, @userId, @tokenHash, @expiresAt)
      ''',
      parameters: {
        'id': _uuid.v4(),
        'userId': userId,
        'tokenHash': tokenHash,
        'expiresAt': expiresAt.toUtc(),
      },
    );
  }

  @override
  Future<PasswordResetRecord?> findValidPasswordReset(String tokenHash) async {
    final db = await database.connection;
    final passwordResetRecord = await db.execute(
      '''
      SELECT * FROM password_reset_records
      WHERE token_hash = @tokenHash AND expires_at > NOW() AND used = FALSE
      ''',
      parameters: {'tokenHash': tokenHash},
    );
    if (passwordResetRecord.isEmpty) {
      return null;
    }
    final record = passwordResetRecord.first;
    return PasswordResetRecord.fromMap(record.toColumnMap());
  }

  @override
  Future<PasswordResetRecord?> findValidRefreshToken(String hashToken) async {
    final db = await database.connection;
    final refreshToken = await db.execute(
      '''
      SELECT * FROM refresh_tokens
      WHERE token_hash = @tokenHash AND expires_at > NOW() AND used = FALSE
      ''',
      parameters: {'tokenHash': hashToken},
    );
    if (refreshToken.isEmpty) {
      return null;
    }
    final record = refreshToken.first;
    return PasswordResetRecord.fromMap(record.toColumnMap());
  }

  @override
  Future<void> invalidateAllFor(String uid) async {
    final db = await database.connection;
    await db.execute(
      '''
      UPDATE refresh_tokens
      SET used = TRUE
      WHERE user_id = @userId
      ''',
      parameters: {'userId': uid},
    );
  }

  @override
  Future<void> markPasswordResetUsed(String resetId) async {
    final db = await database.connection;
    await db.execute(
      '''
      UPDATE password_reset_records
      SET used = TRUE
      WHERE id = @resetId
      ''',
      parameters: {'resetId': resetId},
    );
  }

  @override
  Future<void> markUsedRefreshToken(String uid) async {
    final db = await database.connection;
    await db.execute(
      '''
      UPDATE refresh_tokens
      SET used = TRUE
      WHERE user_id = @userId
      ''',
      parameters: {'userId': uid},
    );
  }

  @override
  Future<void> markUsedResetToken(String id) async {
    final db = await database.connection;
    await db.execute(
      '''
      UPDATE password_reset_records
      SET used = TRUE
      WHERE id = @id
      ''',
      parameters: {'id': id},
    );
  }

  @override
  Future<void> resetPassword({
    required String resetId,
    required String userId,
    required String newHash,
  }) async {
    final db = await database.connection;
    await db.run((txn) async {
      await txn.execute(
        '''
        UPDATE users
        SET password_hash = @newHash
        WHERE id = @userId
        ''',
        parameters: {'newHash': newHash, 'userId': userId},
      );
      await txn.execute(
        '''
        UPDATE password_reset_records
        SET used = TRUE
        WHERE id = @resetId
        ''',
        parameters: {'resetId': resetId},
      );
    });
  }
}
