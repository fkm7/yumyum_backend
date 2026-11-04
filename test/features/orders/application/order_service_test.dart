import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:yumyum_backend/features/addresses/application/address_service.dart';
import 'package:yumyum_backend/features/addresses/domain/address_repository.dart';
import 'package:yumyum_backend/features/orders/application/order_service.dart';
import 'package:yumyum_backend/features/orders/domain/build_order.dart';
import 'package:yumyum_backend/features/orders/domain/cart_item.dart';
import 'package:yumyum_backend/features/orders/domain/order.dart';
import 'package:yumyum_backend/features/orders/domain/order_repository.dart';
import 'package:yumyum_backend/features/payments/application/payment_method_service.dart';
import 'package:yumyum_backend/features/payments/domain/payment_repository.dart';

import '../../../helpers/entities.dart';
import '../../../helpers/test_context.dart';

class _MockAddressRepository extends Mock implements AddressRepository {}

class _MockPaymentRepository extends Mock implements PaymentRepository {}

/// Stores created orders in memory, so tests can see what was saved.
class _InMemoryOrders implements OrderRepository {
  final Map<String, Order> saved = {};

  @override
  Future<Order> create(Order order) async => saved[order.id] = order;

  @override
  Future<Order?> findById(String id) async => saved[id];

  @override
  Future<List<Order>> findByUser(String userId) async =>
      saved.values.where((o) => o.userId == userId).toList();
}

void main() {
  late _MockAddressRepository addresses;
  late _MockPaymentRepository payments;
  late MockRestaurantRepository restaurants;
  late MockProductRepository products;
  late _InMemoryOrders orders;
  late OrderService service;

  const items = [CartItem(productId: 1, count: 2)];

  setUp(() {
    addresses = _MockAddressRepository();
    payments = _MockPaymentRepository();
    restaurants = MockRestaurantRepository();
    products = MockProductRepository();
    orders = _InMemoryOrders();

    when(() => addresses.findById('address-1'))
        .thenAnswer((_) async => testAddress());
    when(() => addresses.findById('foreign-address'))
        .thenAnswer((_) async => testAddress(userId: 'someone-else'));
    when(() => payments.findById('card-1'))
        .thenAnswer((_) async => testPaymentMethod());
    when(() => payments.findById('foreign-card'))
        .thenAnswer((_) async => testPaymentMethod(userId: 'someone-else'));
    when(() => restaurants.findById(1))
        .thenAnswer((_) async => testRestaurant());
    when(() => restaurants.findById(2))
        .thenAnswer((_) async => testRestaurant(id: 2, isOpen: false));
    when(() => restaurants.findById(999)).thenAnswer((_) async => null);
    when(() => products.findByIds(any()))
        .thenAnswer((_) async => [testProduct()]);

    service = OrderService(
      orders: orders,
      restaurants: restaurants,
      products: products,
      addresses: AddressService(addresses),
      paymentMethods: PaymentMethodService(payments),
      now: () => DateTime.utc(2026, 11, 4, 12),
    );
  });

  Future<PlaceOrderResult> place({
    int restaurantId = 1,
    String addressId = 'address-1',
    String? paymentMethodId,
  }) =>
      service.place(
        userId: 'user-1',
        restaurantId: restaurantId,
        items: items,
        addressId: addressId,
        paymentMethodId: paymentMethodId,
      );

  group('place', () {
    test('prices and saves the order for the caller', () async {
      final result = await place(paymentMethodId: 'card-1');

      final order = (result as OrderPlaced).order;
      expect(order.userId, equals('user-1'));
      expect(order.cost, equals(20000));
      expect(order.orderTime, equals(DateTime.utc(2026, 11, 4, 12)));
      expect(orders.saved, contains(order.id));
    });

    test('allows an order with no payment method', () async {
      expect(await place(), isA<OrderPlaced>());
    });

    // A foreign id must look exactly like a missing one.
    test("treats another user's address as not found", () async {
      final result = await place(addressId: 'foreign-address');

      expect(result, isA<OrderAddressNotFound>());
      expect(orders.saved, isEmpty);
    });

    test("treats another user's payment method as not found", () async {
      final result = await place(paymentMethodId: 'foreign-card');

      expect(result, isA<OrderPaymentMethodNotFound>());
      expect(orders.saved, isEmpty);
    });

    test('reports an unknown restaurant', () async {
      expect(await place(restaurantId: 999), isA<OrderRestaurantNotFound>());
    });

    test('passes pricing failures through without saving', () async {
      final result = await place(restaurantId: 2);

      expect(
        result,
        isA<OrderRejected>()
            .having((r) => r.reason, 'reason', isA<RestaurantClosed>()),
      );
      expect(orders.saved, isEmpty);
    });
  });

  group('find', () {
    test("hides another user's order", () async {
      final placed = (await place() as OrderPlaced).order;

      expect(await service.find('user-1', placed.id), isNotNull);
      expect(await service.find('someone-else', placed.id), isNull);
    });
  });
}
