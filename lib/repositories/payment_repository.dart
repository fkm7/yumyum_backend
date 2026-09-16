import 'package:delmer_backend/models/payment_method.dart';

/// Read and write access to the `payment_methods` table.
abstract class PaymentRepository {
  /// Returns the payment methods saved by the given user, newest first.
  Future<List<PaymentMethod>> findByUser(String userId);

  /// Returns the payment method with the given id, or null when absent.
  ///
  /// Ownership is not checked here; the caller compares
  /// [PaymentMethod.userId], matching the pattern used by
  /// `OrderRepository.findById`.
  Future<PaymentMethod?> findById(String id);

  /// Creates a payment method and returns it.
  ///
  /// When [isDefault] is true, any existing default payment method for
  /// [userId] is unset in the same transaction, so at most one default ever
  /// exists.
  Future<PaymentMethod> create({
    required String userId,
    required String type,
    String? brand,
    String? last4,
    int? expiryMonth,
    int? expiryYear,
    required bool isDefault,
  });

  /// Deletes the payment method with the given id.
  ///
  /// A no-op when no such payment method exists.
  Future<void> delete(String id);
}
