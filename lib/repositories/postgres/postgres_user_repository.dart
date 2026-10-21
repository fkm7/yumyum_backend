import 'package:postgres/postgres.dart';

import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/models/user.dart';
import 'package:yumyum_backend/repositories/user_repository.dart';

/// PostgreSQL-backed [UserRepository].
///
/// Never selects or writes `password_hash`; that column belongs to
/// `PostgresCredentialRepository`.
class PostgresUserRepository implements UserRepository {
  /// Constructs a [PostgresUserRepository] over the given [database].
  const PostgresUserRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<User?> findByEmail(String email) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('''
        SELECT uid, first_name, last_name, email, photo_url
        FROM users WHERE email = @email
      '''),
      parameters: {'email': email},
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first.toColumnMap());
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
    return User.fromMap(result.first.toColumnMap());
  }

  @override
  Future<User?> updateProfile({
    required String uid,
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    final db = await database.connection;
    final existing = await findByUid(uid);
    if (existing == null) return null;

    final merged = existing.copyWith(
      firstName: firstName,
      lastName: lastName,
      email: email,
      photoUrl: existing.photoUrl,
    );

    final result = await db.execute(
      Sql.named('''
        UPDATE users SET
          first_name = @first_name, last_name = @last_name, email = @email
        WHERE uid = @uid
      '''),
      parameters: {
        'uid': uid,
        'first_name': merged.firstName,
        'last_name': merged.lastName,
        'email': merged.email != existing.email ? merged.email : existing.email,
      },
    );

    return result.isEmpty ? null : User.fromMap(result.first.toColumnMap());
  }

  @override
  Future<String?> getPhotoUri({required String uid}) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('SELECT photo_url FROM users WHERE uid = @uid'),
      parameters: {'uid': uid},
    );
    if (result.isEmpty) return null;
    return result.first.toColumnMap()['photo_url'] as String?;
  }

  @override
  Future<void> updatePhotoUri({
    required String uid,
    required String photoUrl,
  }) async {
    final db = await database.connection;
    await db.execute(
      Sql.named('UPDATE users SET photo_url = @photo_url WHERE uid = @uid'),
      parameters: {'uid': uid, 'photo_url': photoUrl},
    );
  }

  @override
  Future<void> delete(String uid) async {
    final conn = await database.connection;
    await conn.runTx((session) async {
      // Scrub PII snapshots on this user's past orders before detaching them.
      // The orders.user_id ON DELETE SET NULL constraint (see
      // db/migrations/004_orders_survive_user_deletion.sql) only clears
      // user_id when the DELETE below runs — it does not reach into these
      // JSONB columns, so that has to happen explicitly and in the same
      // transaction.
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
