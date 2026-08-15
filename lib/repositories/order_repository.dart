import 'package:delmer_backend/models/order.dart';

/// Read and write access to the `orders` table.
abstract class OrderRepository {
  /// Returns the orders placed by the given user, newest first.
  Future<List<Order>> findByUser(String userId);

  /// Returns the order with the given id, or null when absent.
  ///
  /// Ownership is not checked here; the caller compares [Order.userId].
  Future<Order?> findById(String id);

  /// Persists [order] and returns it.
  Future<Order> create(Order order);
}
