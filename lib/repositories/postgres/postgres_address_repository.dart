import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/models/address.dart';
import 'package:yumyum_backend/repositories/address_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

const _columns = '''
  id, user_id, type, label, street, city, country, latitude, longitude,
  is_default
''';

/// PostgreSQL-backed [AddressRepository].
class PostgresAddressRepository implements AddressRepository {
  /// Constructs a [PostgresAddressRepository] over the given [database].
  const PostgresAddressRepository(this.database, {Uuid uuid = const Uuid()})
      : _uuid = uuid;

  /// The database whose connection this repository executes against.
  final DatabaseService database;
  final Uuid _uuid;

  @override
  Future<List<Address>> findByUser(String userId) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named(
        'SELECT $_columns FROM addresses WHERE user_id = @user_id '
        'ORDER BY created_at DESC',
      ),
      parameters: {'user_id': userId},
    );
    return result.map((row) => Address.fromRow(row.toColumnMap())).toList();
  }

  @override
  Future<Address?> findById(String id) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('SELECT $_columns FROM addresses WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return Address.fromRow(result.first.toColumnMap());
  }

  @override
  Future<Address> create({
    required String userId,
    required String type,
    required String street,
    required String city,
    required String country,
    required bool isDefault,
    String? label,
    double? latitude,
    double? longitude,
  }) async {
    final db = await database.connection;
    final id = _uuid.v4();

    await db.runTx((session) async {
      // Cleared before the insert, inside the same transaction, so a
      // concurrent read never sees two defaults or zero defaults.
      if (isDefault) {
        await session.execute(
          Sql.named(
            'UPDATE addresses SET is_default = false '
            'WHERE user_id = @user_id AND is_default',
          ),
          parameters: {'user_id': userId},
        );
      }
      await session.execute(
        Sql.named('''
          INSERT INTO addresses
            (id, user_id, type, label, street, city, country, latitude,
             longitude, is_default, created_at)
          VALUES
            (@id, @user_id, @type, @label, @street, @city, @country,
             @latitude, @longitude, @is_default, @created_at)
        '''),
        parameters: {
          'id': id,
          'user_id': userId,
          'type': type,
          'label': label,
          'street': street,
          'city': city,
          'country': country,
          'latitude': latitude,
          'longitude': longitude,
          'is_default': isDefault,
          'created_at': DateTime.now().toUtc(),
        },
      );
    });

    return Address(
      id: id,
      userId: userId,
      type: type,
      label: label,
      street: street,
      city: city,
      country: country,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
    );
  }

  @override
  Future<Address?> update(
    String id, {
    String? type,
    String? label,
    String? street,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) async {
    final existing = await findById(id);
    if (existing == null) return null;

    // Merged ahead of the transaction so callers who omit a field keep the
    // existing value, matching the "apply only the non-null fields"
    // contract on AddressRepository.update.
    final merged = Address(
      id: existing.id,
      userId: existing.userId,
      type: type ?? existing.type,
      label: label ?? existing.label,
      street: street ?? existing.street,
      city: city ?? existing.city,
      country: country ?? existing.country,
      latitude: latitude ?? existing.latitude,
      longitude: longitude ?? existing.longitude,
      isDefault: isDefault ?? existing.isDefault,
    );

    final db = await database.connection;
    await db.runTx((session) async {
      if (merged.isDefault) {
        await session.execute(
          Sql.named(
            'UPDATE addresses SET is_default = false '
            'WHERE user_id = @user_id AND is_default AND id != @id',
          ),
          parameters: {'user_id': merged.userId, 'id': id},
        );
      }
      await session.execute(
        Sql.named('''
          UPDATE addresses SET
            type = @type, label = @label, street = @street, city = @city,
            country = @country, latitude = @latitude, longitude = @longitude,
            is_default = @is_default
          WHERE id = @id
        '''),
        parameters: {
          'id': id,
          'type': merged.type,
          'label': merged.label,
          'street': merged.street,
          'city': merged.city,
          'country': merged.country,
          'latitude': merged.latitude,
          'longitude': merged.longitude,
          'is_default': merged.isDefault,
        },
      );
    });

    return merged;
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.connection;
    await db.execute(
      Sql.named('DELETE FROM addresses WHERE id = @id'),
      parameters: {'id': id},
    );
  }
}
