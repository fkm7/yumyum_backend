import 'package:yumyum_backend/features/payments/domain/payment_method.dart';
import 'package:yumyum_backend/features/payments/domain/payment_repository.dart';

/// A user's saved payment methods.
///
/// Every operation is scoped to `userId`: a payment method owned by someone
/// else is treated exactly like one that does not exist.
///
/// Only display-safe fields are ever stored — never a full card number or
/// CVV. A real gateway integration should resolve cards via a provider token,
/// not via anything a client sends here.
class PaymentMethodService {
  /// Constructs a [PaymentMethodService].
  const PaymentMethodService(this._payments);

  final PaymentRepository _payments;

  /// Every payment method saved by [userId].
  Future<List<PaymentMethod>> list(String userId) =>
      _payments.findByUser(userId);

  /// The payment method [id] if it belongs to [userId], otherwise null.
  Future<PaymentMethod?> find(String userId, String id) async {
    final method = await _payments.findById(id);
    if (method == null || method.userId != userId) return null;
    return method;
  }

  /// Saves a new payment method for [userId].
  Future<PaymentMethod> create(
    String userId, {
    required String type,
    String? brand,
    String? last4,
    int? expiryMonth,
    int? expiryYear,
    bool isDefault = false,
  }) {
    return _payments.create(
      userId: userId,
      type: type,
      brand: brand,
      last4: last4,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      isDefault: isDefault,
    );
  }

  /// Deletes payment method [id]; false when it does not belong to [userId].
  Future<bool> delete(String userId, String id) async {
    if (await find(userId, id) == null) return false;
    await _payments.delete(id);
    return true;
  }
}
