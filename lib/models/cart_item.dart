/// A single line requested by the client when creating an order.
class CartItem {
  /// Constructs a [CartItem].
  const CartItem({required this.productId, required this.count});

  /// Parses one entry of the request's `products` array.
  ///
  /// Returns null when the entry is not an object, the id is missing or not an
  /// integer, or the count is present but not a positive integer. The route
  /// turns a null into a 422; the previous implementation used unchecked `as`
  /// casts here and answered a malformed body with a 500.
  static CartItem? tryParse(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    final id = value['id'];
    if (id is! int) return null;

    final rawCount = value['count'];
    if (rawCount != null && rawCount is! int) return null;
    final count = (rawCount as int?) ?? 1;
    if (count < 1) return null;

    return CartItem(productId: id, count: count);
  }

  /// Identifier of the requested product.
  final int productId;

  /// How many units were requested. Always at least 1.
  final int count;
}
