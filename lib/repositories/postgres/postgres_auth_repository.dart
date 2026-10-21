import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/models/credential.dart';
import 'package:yumyum_backend/models/user.dart';
import 'package:yumyum_backend/repositories/auth_repository.dart';

/// PostgreSQL-backed [AuthRepository].
///
/// Credentials live in the `password_hash` column of `users`, so this shares
/// the table with `PostgresUserRepository` but owns that column exclusively.
class PostgresAuthRepository implements AuthRepository {
  /// Constructs a [PostgresAuthRepository] over the given [database].
  const PostgresAuthRepository(this.database, {Uuid uuid = const Uuid()})
      : _uuid = uuid;

  /// PostgreSQL error code for a unique constraint violation.
  static const _uniqueViolation = '23505';

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  final Uuid _uuid;

  @override
  Future<User?> createAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String passwordHash,
  }) async {
    final db = await database.connection;
    try {
      final result = await db.execute(
        Sql.named('''
          INSERT INTO users
            (uid, first_name, last_name, email, password_hash, photo_url)
          VALUES
            (@uid, @first_name, @last_name, @email, @password_hash, @photo_url)
          RETURNING uid, first_name, last_name, email, photo_url
        '''),
        parameters: {
          'uid': _uuid.v4(),
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password_hash': passwordHash,
          'photo_url': '',
        },
      );
      return User.fromMap(result.first.toColumnMap());
    } on ServerException catch (e) {
      if (e.code == _uniqueViolation) return null;
      rethrow;
    }
  }

  @override
  Future<Credential?> findByEmail(String email) => _findBy('email', email);

  @override
  Future<Credential?> findByUid(String uid) => _findBy('uid', uid);

  Future<Credential?> _findBy(String column, String value) async {
    final db = await database.connection;
    final result = await db.execute(
      // column is one of two literals above, never caller input.
      Sql.named('SELECT uid, password_hash FROM users WHERE $column = @value'),
      parameters: {'value': value},
    );
    if (result.isEmpty) return null;
    return Credential.fromMap(result.first.toColumnMap());
  }

  @override
  Future<void> updatePasswordHash(String uid, String passwordHash) async {
    final db = await database.connection;
    await db.execute(
      Sql.named(
        'UPDATE users SET password_hash = @password_hash WHERE uid = @uid',
      ),
      parameters: {'uid': uid, 'password_hash': passwordHash},
    );
  }
}
