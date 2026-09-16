/// A model class representing a user's saved payment method.
///
/// No card number or CVV is ever held here — only display fields. A real
/// gateway integration (Stripe, etc.) would add a `providerToken` field
/// carrying the tokenized reference and resolve charges through the gateway,
/// not through anything stored on this model.
class PaymentMethod {
  /// Constructs a [PaymentMethod] with the given properties.
  const PaymentMethod({
    required this.id,
    required this.userId,
    required this.type,
    this.brand,
    this.last4,
    this.expiryMonth,
    this.expiryYear,
    required this.isDefault,
  });

  /// Builds a [PaymentMethod] from a database column map.
  factory PaymentMethod.fromRow(Map<String, dynamic> row) {
    return PaymentMethod(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      type: row['type'] as String,
      brand: row['brand'] as String?,
      last4: row['last4'] as String?,
      expiryMonth: row['expiry_month'] as int?,
      expiryYear: row['expiry_year'] as int?,
      isDefault: row['is_default'] as bool,
    );
  }

  /// Payment method identifier.
  final String id;

  /// Identifier of the user this payment method belongs to.
  ///
  /// Deliberately excluded from [toJson], matching [Address] and [Order].
  final String userId;

  /// Kind of payment method, e.g. "card", "cash".
  final String type;

  /// Card brand, e.g. "visa", "mastercard". Null for non-card types.
  final String? brand;

  /// Last four digits, for display only. Null for non-card types.
  final String? last4;

  /// Card expiry month (1-12). Null for non-card types.
  final int? expiryMonth;

  /// Card expiry year. Null for non-card types.
  final int? expiryYear;

  /// Whether this is the user's default payment method.
  final bool isDefault;

  /// The JSON representation of this payment method.
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'brand': brand,
        'last4': last4,
        'expiry_month': expiryMonth,
        'expiry_year': expiryYear,
        'is_default': isDefault,
      };
}
