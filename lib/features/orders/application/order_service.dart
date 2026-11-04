import 'package:uuid/uuid.dart';
import 'package:yumyum_backend/features/addresses/application/address_service.dart';
import 'package:yumyum_backend/features/catalog/domain/product_repository.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant_repository.dart';
import 'package:yumyum_backend/features/orders/domain/build_order.dart';
import 'package:yumyum_backend/features/orders/domain/cart_item.dart';
import 'package:yumyum_backend/features/orders/domain/order.dart';
import 'package:yumyum_backend/features/orders/domain/order_repository.dart';
import 'package:yumyum_backend/features/payments/application/payment_method_service.dart';
import 'package:yumyum_backend/features/payments/domain/payment_method.dart';

/// The outcome of placing an order.
sealed class PlaceOrderResult {
  const PlaceOrderResult();
}

/// The order was priced and saved.
class OrderPlaced extends PlaceOrderResult {
  /// Constructs an [OrderPlaced].
  const OrderPlaced(this.order);

  /// The saved order.
  final Order order;
}

/// The delivery address is unknown or belongs to someone else.
class OrderAddressNotFound extends PlaceOrderResult {
  /// Constructs an [OrderAddressNotFound].
  const OrderAddressNotFound();
}

/// The payment method is unknown or belongs to someone else.
class OrderPaymentMethodNotFound extends PlaceOrderResult {
  /// Constructs an [OrderPaymentMethodNotFound].
  const OrderPaymentMethodNotFound();
}

/// The restaurant does not exist.
class OrderRestaurantNotFound extends PlaceOrderResult {
  /// Constructs an [OrderRestaurantNotFound].
  const OrderRestaurantNotFound();
}

/// The cart itself was rejected; [reason] says why.
class OrderRejected extends PlaceOrderResult {
  /// Constructs an [OrderRejected].
  const OrderRejected(this.reason);

  /// The pricing rule the cart failed.
  final OrderBuildFailure reason;
}

/// Places and reads a user's orders.
class OrderService {
  /// Constructs an [OrderService].
  OrderService({
    required OrderRepository orders,
    required RestaurantRepository restaurants,
    required ProductRepository products,
    required AddressService addresses,
    required PaymentMethodService paymentMethods,
    Uuid uuid = const Uuid(),
    DateTime Function() now = DateTime.now,
  })  : _orders = orders,
        _restaurants = restaurants,
        _products = products,
        _addresses = addresses,
        _paymentMethods = paymentMethods,
        _uuid = uuid,
        _now = now;

  final OrderRepository _orders;
  final RestaurantRepository _restaurants;
  final ProductRepository _products;
  final AddressService _addresses;
  final PaymentMethodService _paymentMethods;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// Every order placed by [userId].
  Future<List<Order>> list(String userId) => _orders.findByUser(userId);

  /// The order [id] if it belongs to [userId], otherwise null.
  ///
  /// A foreign order is indistinguishable from a missing one, so a caller
  /// cannot tell someone else's order id from an unused one.
  Future<Order?> find(String userId, String id) async {
    final order = await _orders.findById(id);
    if (order == null || order.userId != userId) return null;
    return order;
  }

  /// Prices [items] from [restaurantId] into an order for [userId] and saves
  /// it.
  ///
  /// [paymentMethodId] is optional: cash-on-delivery orders have none.
  Future<PlaceOrderResult> place({
    required String userId,
    required int restaurantId,
    required List<CartItem> items,
    required String addressId,
    String? paymentMethodId,
  }) async {
    final address = await _addresses.find(userId, addressId);
    if (address == null) return const OrderAddressNotFound();

    PaymentMethod? paymentMethod;
    if (paymentMethodId != null) {
      paymentMethod = await _paymentMethods.find(userId, paymentMethodId);
      if (paymentMethod == null) return const OrderPaymentMethodNotFound();
    }

    final restaurant = await _restaurants.findById(restaurantId);
    if (restaurant == null) return const OrderRestaurantNotFound();

    final available =
        await _products.findByIds(items.map((i) => i.productId).toList());

    final result = buildOrder(
      orderId: _uuid.v4(),
      userId: userId,
      restaurant: restaurant,
      available: available,
      requested: items,
      orderTime: _now().toUtc(),
      address: address,
      paymentMethod: paymentMethod,
    );

    return switch (result) {
      OrderBuilt(:final order) => OrderPlaced(await _orders.create(order)),
      final OrderBuildFailure failure => OrderRejected(failure),
    };
  }
}
