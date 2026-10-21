import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/models/payment_method.dart';
import 'package:yumyum_backend/repositories/payment_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

const _columns = '''
  id, user_id, type, brand, last4, expiry_month, expiry_year, is_default
''';

/// PostgreSQL-backed [PaymentRepository].
class PostgresPaymentRepository implements PaymentRepository {
  /// Constructs a [PostgresPaymentRepository] over the given [database].
  const PostgresPaymentRepository(this.database, {Uuid uuid = const Uuid()})
      : _uuid = uuid;

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  final Uuid _uuid;

  @override
  Future<List<PaymentMethod>> findByUser(String userId) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named(
        'SELECT $_columns FROM payment_methods WHERE user_id = @user_id '
        'ORDER BY created_at DESC',
      ),
      parameters: {'user_id': userId},
    );
    return result
        .map((row) => PaymentMethod.fromRow(row.toColumnMap()))
        .toList();
  }

  @override
  Future<PaymentMethod?> findById(String id) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('SELECT $_columns FROM payment_methods WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return PaymentMethod.fromRow(result.first.toColumnMap());
  }

  @override
  Future<PaymentMethod> create({
    required String userId,
    required String type,
    required bool isDefault,
    String? brand,
    String? last4,
    int? expiryMonth,
    int? expiryYear,
  }) async {
    final db = await database.connection;
    final id = _uuid.v4();

    await db.runTx((session) async {
      if (isDefault) {
        await session.execute(
          Sql.named(
            'UPDATE payment_methods SET is_default = false '
            'WHERE user_id = @user_id AND is_default',
          ),
          parameters: {'user_id': userId},
        );
      }
      await session.execute(
        Sql.named('''
          INSERT INTO payment_methods
            (id, user_id, type, brand, last4, expiry_month, expiry_year,
             is_default, created_at)
          VALUES
            (@id, @user_id, @type, @brand, @last4, @expiry_month,
             @expiry_year, @is_default, @created_at)
        '''),
        parameters: {
          'id': id,
          'user_id': userId,
          'type': type,
          'brand': brand,
          'last4': last4,
          'expiry_month': expiryMonth,
          'expiry_year': expiryYear,
          'is_default': isDefault,
          'created_at': DateTime.now().toUtc(),
        },
      );
    });

    return PaymentMethod(
      id: id,
      userId: userId,
      type: type,
      brand: brand,
      last4: last4,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      isDefault: isDefault,
    );
  }

  @override
  Future<void> delete(String id) async {
    final db = await database.connection;
    await db.execute(
      Sql.named('DELETE FROM payment_methods WHERE id = @id'),
      parameters: {'id': id},
    );
  }
}
