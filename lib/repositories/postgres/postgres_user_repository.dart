import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import 'package:yumyum_backend/db/database_service.dart';
import 'package:yumyum_backend/models/user.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';

/// PostgreSQL-backed [UserRepository].
class PostgresUserRepository implements UserRepository {
  /// Constructs a [PostgresUserRepository] over the given [database].
  const PostgresUserRepository(this.database, {Uuid uuid = const Uuid()})
      : _uuid = uuid;

  /// PostgreSQL error code for a unique constraint violation.
  static const _uniqueViolation = '23505';

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  final Uuid _uuid;

  @override
  Future<User?> findByEmail(String email) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('''
        SELECT uid, first_name, last_name, email, password_hash, photo_url
        FROM users WHERE email = @email
      '''),
      parameters: {'email': email},
    );
    if (result.isEmpty) return null;
    return User.fromRow(result.first.toColumnMap());
  }

  @override
  Future<User?> findByUid(String uid) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('''
        SELECT uid, first_name, last_name, email, photo_url
        FROM users WHERE uid = @uid
      '''),
      parameters: {'uid': uid},
    );
    if (result.isEmpty) return null;
    return User.fromRow(result.first.toColumnMap());
  }

  @override
  Future<User?> create({
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
      return User.fromRow(result.first.toColumnMap());
    } on ServerException catch (e) {
      if (e.code == _uniqueViolation) return null;
      rethrow;
    }
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

  @override
    Future<User?> updateProfile(
      String uid, {
      String? firstName,
      String? lastName,
      String? photoUrl,
    }) async {
      final existing = await findByUid(uid);
      if (existing == null) return null;

      final merged = User(
        uid: existing.uid,
        firstName: firstName ?? existing.firstName,
        lastName: lastName ?? existing.lastName,
        email: existing.email,
        photoUrl: photoUrl ?? existing.photoUrl,
      );

      final conn = await database.connection;
      await conn.execute(
        Sql.named('''
        UPDATE users SET
          first_name = @first_name, last_name = @last_name,
          photo_url = @photo_url
        WHERE uid = @uid
      '''),
        parameters: {
          'uid': uid,
          'first_name': merged.firstName,
          'last_name': merged.lastName,
          'photo_url': merged.photoUrl,
        },
      );

      return merged;
    }

    @override
    Future<void> delete(String uid) async {
      final conn = await database.connection;
      await conn.runTx((session) async {
        // Scrub PII snapshots on this user's past orders before detaching them.
        // The orders.user_id ON DELETE SET NULL constraint (see
        // db/account_deletion_schema.sql) only clears user_id when the DELETE
        // below runs — it does not reach into these JSONB columns, so that has
        // to happen explicitly and in the same transaction.
        await session.execute(
          Sql.named('''
          UPDATE orders
          SET delivery_address = NULL, payment_detail = NULL
          WHERE user_id = @uid
        '''),
          parameters: {'uid': uid},
        );

        // Cascades to favorites, addresses, payment_methods and
        // refresh_tokens via their own ON DELETE CASCADE constraints, and
        // detaches (rather than deletes) this user's orders via the
        // ON DELETE SET NULL constraint above.
        await session.execute(
          Sql.named('DELETE FROM users WHERE uid = @uid'),
          parameters: {'uid': uid},
        );
      });
    }
  }
}
