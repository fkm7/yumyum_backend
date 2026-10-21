import 'dart:convert';

import 'package:yumyum_backend/core/db/database_service.dart';
import 'package:yumyum_backend/models/order.dart';
import 'package:yumyum_backend/repositories/order_repository.dart';
import 'package:postgres/postgres.dart';

const _columns = '''
  id, user_id, cost, status, order_time, restaurant_info, products,
  address_id, delivery_address, courier, payment_method_id, payment_detail
''';

/// PostgreSQL-backed [OrderRepository].
class PostgresOrderRepository implements OrderRepository {
  /// Constructs a [PostgresOrderRepository] over the given [database].
  const PostgresOrderRepository(this.database);

  /// The database whose connection this repository executes against.
  final DatabaseService database;

  @override
  Future<List<Order>> findByUser(String userId) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named(
        'SELECT $_columns FROM orders WHERE user_id = @user_id '
        'ORDER BY order_time DESC',
      ),
      parameters: {'user_id': userId},
    );
    return result.map((row) => Order.fromMap(row.toColumnMap())).toList();
  }

  @override
  Future<Order?> findById(String id) async {
    final db = await database.connection;
    final result = await db.execute(
      Sql.named('SELECT $_columns FROM orders WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return Order.fromMap(result.first.toColumnMap());
  }

  @override
  Future<Order> create(Order order) async {
    final db = await database.connection;
    await db.execute(
      Sql.named('''
        INSERT INTO orders
          (id, user_id, cost, status, order_time, restaurant_info, products,
           address_id, delivery_address, courier, payment_method_id,
           payment_detail)
        VALUES
          (@id, @user_id, @cost, @status, @order_time, @restaurant_info::jsonb,
           @products::jsonb, @address_id, @delivery_address::jsonb, NULL,
           @payment_method_id, @payment_detail::jsonb)
      '''),
      parameters: {
        'id': order.id,
        'user_id': order.userId,
        'cost': order.cost,
        'status': order.status,
        'order_time': order.orderTime,
        'restaurant_info': jsonEncode(order.restaurantInfo),
        'products': jsonEncode(
          order.products.map((p) => p.toJson()).toList(),
        ),
        'address_id': order.addressId,
        'delivery_address': order.deliveryAddress == null
            ? null
            : jsonEncode(order.deliveryAddress),
        'payment_method_id': order.paymentMethodId,
        'payment_detail': order.paymentDetail == null
            ? null
            : jsonEncode(order.paymentDetail),
      },
    );
    return order;
  }
}
