import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/models/order.dart';
import 'package:delmer_backend/models/product.dart';
import 'package:delmer_backend/models/restaurant.dart';
import 'package:delmer_backend/repositories/order_repository.dart';
import 'package:delmer_backend/repositories/product_repository.dart';
import 'package:delmer_backend/repositories/restaurant_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../routes/api/v1/orders/[id].dart' as order_by_id;
import '../../../../routes/api/v1/orders/index.dart' as orders;
import '../../../helpers/test_context.dart';

const _restaurant = Restaurant(
  id: 1,
  name: 'Burger House',
  isOpen: true,
  rating: 4.5,
  logo: null,
  address: {'city': 'Tashkent'},
  image: null,
  cuisine: 1,
  startTime: '09:00',
  endTime: '23:00',
  description: null,
  phoneNumber: null,
  deliveryCost: 5000,
  minDeliveryTime: 20,
  maxDeliveryTime: 40,
  freeDeliveryFrom: 50000,
  productCategories: [1],
);

Product _product({
  int id = 1,
  int restaurantId = 1,
  double price = 25000,
  String status = 'available',
}) =>
    Product(
      id: id,
      restaurantId: restaurantId,
      category: 1,
      price: price,
      status: status,
      titleEn: 'Classic Burger',
      titleRu: null,
      titleUz: null,
      image: null,
      description: null,
    );

Order _order({String id = 'order-1', String userId = 'user-1'}) => Order(
      id: id,
      userId: userId,
      cost: 25000,
      status: 'received',
      orderTime: DateTime.utc(2026, 8, 15, 12),
      restaurantInfo: _restaurant.toJson(),
      products: [OrderProduct.from(_product(), 1)],
      deliveryAddress: null,
      courier: null,
      paymentDetail: null,
    );

class _Harness {
  _Harness({
    Restaurant? restaurant = _restaurant,
    List<Product> products = const [],
    List<Order> userOrders = const [],
    Order? orderById,
  }) {
    when(() => restaurants.findById(any())).thenAnswer((_) async => restaurant);
    when(() => this.products.findByIds(any()))
        .thenAnswer((_) async => products);
    when(() => orders.findByUser(any())).thenAnswer((_) async => userOrders);
    when(() => orders.findById(any())).thenAnswer((_) async => orderById);
    when(() => orders.create(any())).thenAnswer(
      (invocation) async => invocation.positionalArguments.first as Order,
    );
  }

  final restaurants = MockRestaurantRepository();
  final products = MockProductRepository();
  final orders = MockOrderRepository();

  TestContext context(Request request, {String? uid = 'user-1'}) {
    final context = TestContext(request: request)
      ..provide<RestaurantRepository>(restaurants)
      ..provide<ProductRepository>(products)
      ..provide<OrderRepository>(orders);
    if (uid != null) context.authenticateAs(uid);
    return context;
  }
}

class _FakeOrder extends Fake implements Order {}

Map<String, dynamic> _cart({
  int restaurantId = 1,
  List<Map<String, dynamic>> products = const [
    {'id': 1, 'count': 1},
  ],
}) =>
    {'restaurantId': restaurantId, 'products': products};

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeOrder());
    registerFallbackValue(<int>[]);
  });

  group('POST /api/v1/orders', () {
    test('rejects methods other than GET and POST', () async {
      final harness = _Harness();
      await expectMethodNotAllowed(
        (request) async => orders.onRequest(harness.context(request).context),
        allowed: {'GET', 'POST'},
      );
    });

    test('responds 400 for a malformed JSON body', () async {
      final harness = _Harness();
      final response = await orders.onRequest(
        harness
            .context(Request('POST', Uri.parse('http://localhost/'), body: '{'))
            .context,
      );
      expect(response.statusCode, equals(400));
    });

    group('responds 422 for a malformed cart', () {
      // Each of these hit an unchecked `as` cast in the old implementation and
      // surfaced as a 500 rather than a validation error.
      final bad = <String, Map<String, dynamic>>{
        'missing restaurantId': {
          'products': [
            {'id': 1},
          ],
        },
        'string restaurantId': _cart()..['restaurantId'] = '1',
        'missing products': {'restaurantId': 1},
        'empty products': _cart(products: []),
        'products is not a list': {'restaurantId': 1, 'products': 'nope'},
        'product entry is a scalar': {
          'restaurantId': 1,
          'products': [42],
        },
        'product id is a string': _cart(
          products: [
            {'id': '1', 'count': 1},
          ],
        ),
        'product count is a string': _cart(
          products: [
            {'id': 1, 'count': 'two'},
          ],
        ),
        'product count is zero': _cart(
          products: [
            {'id': 1, 'count': 0},
          ],
        ),
        'product count is negative': _cart(
          products: [
            {'id': 1, 'count': -3},
          ],
        ),
      };

      for (final entry in bad.entries) {
        test(entry.key, () async {
          final harness = _Harness(products: [_product()]);
          final response = await orders.onRequest(
            harness.context(jsonRequest('POST', body: entry.value)).context,
          );
          expect(response.statusCode, equals(422));
        });
      }
    });

    test('responds 404 for an unknown restaurant', () async {
      final harness = _Harness(restaurant: null);
      final response = await orders.onRequest(
        harness.context(jsonRequest('POST', body: _cart())).context,
      );
      expect(response.statusCode, equals(404));
    });

    // The old implementation skipped unknown products, so this cart produced
    // a 201 with an empty product list and a cost of 0.
    test('responds 404 rather than creating an empty order', () async {
      final harness = _Harness();
      final response = await orders.onRequest(
        harness.context(jsonRequest('POST', body: _cart())).context,
      );

      expect(response.statusCode, equals(404));
      verifyNever(() => harness.orders.create(any()));
    });

    test('responds 409 when the restaurant is closed', () async {
      final harness = _Harness(
        restaurant: Restaurant(
          id: _restaurant.id,
          name: _restaurant.name,
          isOpen: false,
          rating: _restaurant.rating,
          logo: _restaurant.logo,
          address: _restaurant.address,
          image: _restaurant.image,
          cuisine: _restaurant.cuisine,
          startTime: _restaurant.startTime,
          endTime: _restaurant.endTime,
          description: _restaurant.description,
          phoneNumber: _restaurant.phoneNumber,
          deliveryCost: _restaurant.deliveryCost,
          minDeliveryTime: _restaurant.minDeliveryTime,
          maxDeliveryTime: _restaurant.maxDeliveryTime,
          freeDeliveryFrom: _restaurant.freeDeliveryFrom,
          productCategories: _restaurant.productCategories,
        ),
        products: [_product()],
      );
      final response = await orders.onRequest(
        harness.context(jsonRequest('POST', body: _cart())).context,
      );

      expect(response.statusCode, equals(409));
      verifyNever(() => harness.orders.create(any()));
    });

    test('responds 409 for an unavailable product', () async {
      final harness = _Harness(products: [_product(status: 'sold_out')]);
      final response = await orders.onRequest(
        harness.context(jsonRequest('POST', body: _cart())).context,
      );

      expect(response.statusCode, equals(409));
      expect(
        (await jsonBody(response) as Map)['product_ids'],
        equals([1]),
      );
      verifyNever(() => harness.orders.create(any()));
    });

    test('responds 422 for products from another restaurant', () async {
      final harness = _Harness(products: [_product(restaurantId: 2)]);
      final response = await orders.onRequest(
        harness.context(jsonRequest('POST', body: _cart())).context,
      );

      expect(response.statusCode, equals(422));
      verifyNever(() => harness.orders.create(any()));
    });

    group('on success', () {
      Future<Map<String, dynamic>> create({
        List<Map<String, dynamic>>? products,
      }) async {
        final harness = _Harness(
          products: [_product(), _product(id: 2, price: 35000)],
        );
        final response = await orders.onRequest(
          harness
              .context(
                jsonRequest(
                  'POST',
                  body: products == null ? _cart() : _cart(products: products),
                ),
              )
              .context,
        );
        expect(response.statusCode, equals(201));
        return await jsonBody(response) as Map<String, dynamic>;
      }

      test('prices the order', () async {
        final json = await create(
          products: [
            {'id': 1, 'count': 2},
            {'id': 2, 'count': 1},
          ],
        );
        expect(json['cost'], equals(85000));
      });

      test('gives each line its own total', () async {
        final json = await create(
          products: [
            {'id': 1, 'count': 1},
            {'id': 2, 'count': 1},
          ],
        );
        final lines = json['products']! as List<dynamic>;
        expect(
          lines.map((l) => (l as Map)['sub_total']),
          equals([25000, 35000]),
        );
        expect(lines.map((l) => (l as Map)['total']), equals([25000, 35000]));
      });

      test('attributes the order to the authenticated user', () async {
        final harness = _Harness(products: [_product()]);
        final response = await orders.onRequest(
          harness
              .context(jsonRequest('POST', body: _cart()), uid: 'someone-else')
              .context,
        );
        expect(response.statusCode, equals(201));

        final saved = verify(() => harness.orders.create(captureAny()))
            .captured
            .single as Order;
        expect(saved.userId, equals('someone-else'));
      });

      test('serialises order_time as ISO-8601', () async {
        final json = await create();
        expect(
          DateTime.parse(json['order_time'] as String),
          isA<DateTime>(),
        );
      });

      test('assigns a non-numeric unique id', () async {
        final first = await create();
        final second = await create();
        expect(first['id'], isNot(equals(second['id'])));
        expect(int.tryParse(first['id'] as String), isNull);
      });
    });
  });

  group('GET /api/v1/orders', () {
    // Before the auth middleware existed this returned every order in the
    // system to any caller.
    test("lists only the authenticated user's orders", () async {
      final harness = _Harness(userOrders: [_order()]);
      final response = await orders.onRequest(
        harness.context(jsonRequest('GET')).context,
      );

      expect(response.statusCode, equals(200));
      verify(() => harness.orders.findByUser('user-1')).called(1);
    });

    test('returns an empty array when the user has no orders', () async {
      final harness = _Harness();
      final response = await orders.onRequest(
        harness.context(jsonRequest('GET')).context,
      );
      expect(await jsonBody(response), isEmpty);
    });
  });

  group('GET /api/v1/orders/[id]', () {
    Future<Response> invoke(String id, {Order? found, String uid = 'user-1'}) {
      final harness = _Harness(orderById: found);
      return Future.value(harness.context(jsonRequest('GET'), uid: uid).context)
          .then((c) => order_by_id.onRequest(c, id));
    }

    test('rejects every method except GET', () async {
      final harness = _Harness(orderById: _order());
      await expectMethodNotAllowed(
        (request) async => order_by_id.onRequest(
          harness.context(request).context,
          'order-1',
        ),
        allowed: {'GET'},
      );
    });

    test('responds 404 for an unknown order', () async {
      expect((await invoke('nope')).statusCode, equals(404));
    });

    // A foreign order must be indistinguishable from a missing one, or the
    // endpoint leaks which order ids exist.
    test('responds 404 for an order belonging to another user', () async {
      final response = await invoke(
        'order-1',
        found: _order(userId: 'someone-else'),
      );
      expect(response.statusCode, equals(404));
    });

    test('answers identically for a missing and a foreign order', () async {
      final missing = await invoke('nope');
      final foreign = await invoke(
        'order-1',
        found: _order(userId: 'someone-else'),
      );
      expect(missing.statusCode, equals(foreign.statusCode));
      expect(await jsonBody(missing), equals(await jsonBody(foreign)));
    });

    test("responds 200 for the caller's own order", () async {
      final response = await invoke('order-1', found: _order());
      expect(response.statusCode, equals(200));
      final json = await jsonBody(response) as Map<String, dynamic>;
      expect(json['id'], equals('order-1'));
      expect(json['order_time'], equals('2026-08-15T12:00:00.000Z'));
    });
  });
}
