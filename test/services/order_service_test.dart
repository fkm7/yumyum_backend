import 'package:delmer_backend/models/cart_item.dart';
import 'package:delmer_backend/models/category.dart';
import 'package:delmer_backend/models/cuisine.dart';
import 'package:delmer_backend/models/product.dart';
import 'package:delmer_backend/models/restaurant.dart';
import 'package:delmer_backend/models/restaurant_category.dart';
import 'package:delmer_backend/services/order_service.dart';
import 'package:test/test.dart';

const _category = Category(
  id: 1,
  titleEn: 'Burgers',
  titleRu: 'Бургеры',
  titleUz: 'Burgerlar',
  icon: null,
);

const _cuisine = Cuisine(
  id: 1,
  titleEn: 'American',
  titleRu: 'Американская',
  titleUz: 'Amerika oshxonasi',
  icon: null,
);

const _restaurantCategory = RestaurantCategory(
  id: 1,
  titleEn: 'Burgers',
  titleRu: 'Бургеры',
  titleUz: 'Burgerlar',
  icon: null,
);

Restaurant _restaurant({int id = 1, bool isOpen = true}) => Restaurant(
      id: id,
      name: 'Burger House',
      isOpen: isOpen,
      rating: 4.5,
      logo: null,
      address: const {'city': 'Tashkent'},
      image: null,
      cuisine: _cuisine,
      category: _restaurantCategory,
      startTime: '09:00',
      endTime: '23:00',
      description: null,
      phoneNumber: null,
      deliveryCost: 5000,
      minDeliveryTime: 20,
      maxDeliveryTime: 40,
      freeDeliveryFrom: 50000,
      productCategories: const [_category],
    );

Product _product({
  required int id,
  double price = 10000,
  int restaurantId = 1,
  String status = 'available',
}) =>
    Product(
      id: id,
      restaurantId: restaurantId,
      category: _category,
      price: price,
      status: status,
      titleEn: 'Product $id',
      titleRu: null,
      titleUz: null,
      image: null,
      description: null,
      unit: null,
    );

final _orderTime = DateTime.utc(2026, 8, 15, 12);

OrderBuildResult _build({
  required List<Product> available,
  required List<CartItem> requested,
  Restaurant? restaurant,
}) =>
    buildOrder(
      orderId: 'order-1',
      userId: 'user-1',
      restaurant: restaurant ?? _restaurant(),
      available: available,
      requested: requested,
      orderTime: _orderTime,
    );

void main() {
  group('buildOrder', () {
    group('pricing', () {
      test('prices a single line as price * count', () {
        final result = _build(
          available: [_product(id: 1, price: 25000)],
          requested: const [CartItem(productId: 1, count: 2)],
        );

        final order = (result as OrderBuilt).order;
        expect(order.cost, equals(50000));
        expect(order.products.single.subTotal, equals(50000));
      });

      // The previous implementation wrote the running cart total into each
      // line's `total`, so the second line reported the sum of both lines.
      test('gives each line its own total, not the running cart total', () {
        final result = _build(
          available: [
            _product(id: 1, price: 25000),
            _product(id: 2, price: 35000),
            _product(id: 3, price: 12000),
          ],
          requested: const [
            CartItem(productId: 1, count: 1),
            CartItem(productId: 2, count: 1),
            CartItem(productId: 3, count: 1),
          ],
        );

        final order = (result as OrderBuilt).order;
        expect(
          order.products.map((p) => p.subTotal),
          equals([25000, 35000, 12000]),
        );
        expect(
          order.products.map((p) => p.toJson()['total']),
          equals([25000, 35000, 12000]),
        );
        expect(order.cost, equals(72000));
      });

      test('sums every line into the order cost', () {
        final result = _build(
          available: [
            _product(id: 1, price: 25000),
            _product(id: 2, price: 35000),
          ],
          requested: const [
            CartItem(productId: 1, count: 2),
            CartItem(productId: 2, count: 3),
          ],
        );

        expect((result as OrderBuilt).order.cost, equals(155000));
      });

      test('merges duplicate lines for the same product', () {
        final result = _build(
          available: [_product(id: 1)],
          requested: const [
            CartItem(productId: 1, count: 2),
            CartItem(productId: 1, count: 3),
          ],
        );

        final order = (result as OrderBuilt).order;
        expect(order.products, hasLength(1));
        expect(order.products.single.count, equals(5));
        expect(order.cost, equals(50000));
      });

      test('captures the restaurant snapshot and metadata', () {
        final result = _build(
          available: [_product(id: 1)],
          requested: const [CartItem(productId: 1, count: 1)],
        );

        final order = (result as OrderBuilt).order;
        expect(order.id, equals('order-1'));
        expect(order.userId, equals('user-1'));
        expect(order.status, equals('received'));
        expect(order.orderTime, equals(_orderTime));
        expect(order.restaurantInfo['name'], equals('Burger House'));
        expect(order.products.single.institution, equals(1));
      });
    });

    group('validation', () {
      test('rejects an empty cart', () {
        expect(
          _build(available: [], requested: const []),
          isA<EmptyCart>(),
        );
      });

      // Previously unknown products were skipped with `continue`, so a cart of
      // entirely bogus ids produced a 201 with no products and a cost of 0.
      test('reports unknown products instead of silently skipping them', () {
        final result = _build(
          available: [_product(id: 1)],
          requested: const [
            CartItem(productId: 1, count: 1),
            CartItem(productId: 999, count: 1),
          ],
        );

        expect(result, isA<ProductsNotFound>());
        expect((result as ProductsNotFound).productIds, equals([999]));
      });

      test('never produces a zero-cost order from unknown products', () {
        final result = _build(
          available: [],
          requested: const [CartItem(productId: 999, count: 1)],
        );

        expect(result, isA<ProductsNotFound>());
        expect(result, isNot(isA<OrderBuilt>()));
      });

      // Nothing previously checked that ordered products belonged to the
      // restaurant being ordered from.
      test('rejects products belonging to another restaurant', () {
        final result = _build(
          available: [_product(id: 7, restaurantId: 3)],
          requested: const [CartItem(productId: 7, count: 1)],
        );

        expect(result, isA<ProductsFromOtherRestaurant>());
        expect(
          (result as ProductsFromOtherRestaurant).productIds,
          equals([7]),
        );
      });

      test('rejects unavailable products', () {
        final result = _build(
          available: [_product(id: 1, status: 'sold_out')],
          requested: const [CartItem(productId: 1, count: 1)],
        );

        expect(result, isA<ProductsUnavailable>());
        expect((result as ProductsUnavailable).productIds, equals([1]));
      });

      test('rejects orders from a closed restaurant', () {
        final result = _build(
          available: [_product(id: 1)],
          requested: const [CartItem(productId: 1, count: 1)],
          restaurant: _restaurant(isOpen: false),
        );

        expect(result, isA<RestaurantClosed>());
      });

      test('reports every missing product, not just the first', () {
        final result = _build(
          available: [],
          requested: const [
            CartItem(productId: 8, count: 1),
            CartItem(productId: 9, count: 1),
          ],
        );

        expect((result as ProductsNotFound).productIds, equals([8, 9]));
      });
    });
  });
}
