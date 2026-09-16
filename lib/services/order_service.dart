import 'package:delmer_backend/models/address.dart';
import 'package:delmer_backend/models/cart_item.dart';
import 'package:delmer_backend/models/order.dart';
import 'package:delmer_backend/models/payment_method.dart';
import 'package:delmer_backend/models/product.dart';
import 'package:delmer_backend/models/restaurant.dart';

/// The outcome of building an order from a cart.
///
/// Sealed so that routes must handle every failure mode: adding a new variant
/// turns every `switch` over an [OrderBuildResult] into a compile error rather
/// than a silently-missed branch.
sealed class OrderBuildResult {
  const OrderBuildResult();
}

/// The cart was valid and priced into [order].
class OrderBuilt extends OrderBuildResult {
  /// Constructs an [OrderBuilt] carrying the priced [order].
  const OrderBuilt(this.order);

  /// The priced order, not yet persisted.
  final Order order;
}

/// The cart contained no line items.
class EmptyCart extends OrderBuildResult {
  /// Constructs an [EmptyCart].
  const EmptyCart();
}

/// The restaurant is not currently accepting orders.
class RestaurantClosed extends OrderBuildResult {
  /// Constructs a [RestaurantClosed].
  const RestaurantClosed();
}

/// One or more requested products do not exist.
class ProductsNotFound extends OrderBuildResult {
  /// Constructs a [ProductsNotFound] naming the missing [productIds].
  const ProductsNotFound(this.productIds);

  /// The requested ids that no product matched.
  final List<int> productIds;
}

/// One or more requested products belong to a different restaurant.
class ProductsFromOtherRestaurant extends OrderBuildResult {
  /// Constructs a [ProductsFromOtherRestaurant] naming the [productIds].
  const ProductsFromOtherRestaurant(this.productIds);

  /// The requested ids that belong to another restaurant.
  final List<int> productIds;
}

/// One or more requested products are not currently available.
class ProductsUnavailable extends OrderBuildResult {
  /// Constructs a [ProductsUnavailable] naming the [productIds].
  const ProductsUnavailable(this.productIds);

  /// The requested ids whose status is not `available`.
  final List<int> productIds;
}

/// Prices a cart into an [Order].
///
/// Pure: it takes already-fetched entities and returns a result, so every
/// pricing and validation rule below is unit-testable without a database.
///
/// [available] is the set of products the repository found for the requested
/// ids; ids missing from it are reported rather than silently dropped, which is
/// what the previous implementation did (it `continue`d past unknown products
/// and could return a 201 for an empty, zero-cost order).
///
/// [address] and [paymentMethod] are the already-loaded, already
/// ownership-checked entities the route resolved from `addressId` /
/// `paymentMethodId`. Their `toJson()` is snapshotted onto the order the same
/// way [Restaurant.toJson] is snapshotted into `restaurant_info`: the FK can
/// go stale if the address is later edited or deleted, the snapshot cannot.
/// [paymentMethod] is optional — a cash-on-delivery order has none.
OrderBuildResult buildOrder({
  required String orderId,
  required String userId,
  required Restaurant restaurant,
  required List<Product> available,
  required List<CartItem> requested,
  required DateTime orderTime,
  required Address address,
  PaymentMethod? paymentMethod,
}) {
  if (requested.isEmpty) return const EmptyCart();
  if (!restaurant.isOpen) return const RestaurantClosed();

  final byId = {for (final product in available) product.id: product};

  final missing = <int>[];
  final foreign = <int>[];
  final unavailable = <int>[];

  for (final item in requested) {
    final product = byId[item.productId];
    if (product == null) {
      missing.add(item.productId);
    } else if (product.restaurantId != restaurant.id) {
      foreign.add(item.productId);
    } else if (product.status != 'available') {
      unavailable.add(item.productId);
    }
  }

  if (missing.isNotEmpty) return ProductsNotFound(missing);
  if (foreign.isNotEmpty) return ProductsFromOtherRestaurant(foreign);
  if (unavailable.isNotEmpty) return ProductsUnavailable(unavailable);

  // Merge duplicate lines so that ordering the same product twice charges for
  // the combined count once, rather than emitting two lines for one product.
  final counts = <int, int>{};
  for (final item in requested) {
    counts[item.productId] = (counts[item.productId] ?? 0) + item.count;
  }

  final products = [
    for (final entry in counts.entries)
      OrderProduct.from(byId[entry.key]!, entry.value),
  ];

  final cost = products.fold<double>(0, (sum, p) => sum + p.subTotal);

  return OrderBuilt(
    Order(
      id: orderId,
      userId: userId,
      cost: cost,
      status: 'received',
      orderTime: orderTime,
      restaurantInfo: restaurant.toJson(),
      products: products,
      addressId: address.id,
      deliveryAddress: address.toJson(),
      courier: null,
      paymentMethodId: paymentMethod?.id,
      paymentDetail: paymentMethod?.toJson(),
    ),
  );
}
