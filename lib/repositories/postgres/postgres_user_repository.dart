import 'package:delmer_backend/db/database_service.dart';
import 'package:delmer_backend/models/user.dart';
import 'package:delmer_backend/repositories/user_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

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
    final conn = await database.connection;
    final result = await conn.execute(
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
    final conn = await database.connection;
    final result = await conn.execute(
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
    final conn = await database.connection;
    try {
      final result = await conn.execute(
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
}
