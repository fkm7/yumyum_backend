import 'package:delmer_backend/models/cart_item.dart';
import 'package:delmer_backend/models/category.dart';
import 'package:delmer_backend/models/order.dart';
import 'package:delmer_backend/models/product.dart';
import 'package:delmer_backend/models/refresh_token_record.dart';
import 'package:delmer_backend/models/restaurant.dart';
import 'package:delmer_backend/models/user.dart';
import 'package:test/test.dart';

void main() {
  group('User', () {
    test('reads a row that includes the password hash', () {
      final user = User.fromRow(const {
        'uid': 'user-1',
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'ada@example.com',
        'password_hash': 'digest',
        'photo_url': '',
      });

      expect(user.passwordHash, equals('digest'));
    });

    // /auth/me never selects password_hash, so fromRow has to tolerate its
    // absence rather than throwing on a missing key.
    test('reads a row that omits the password hash', () {
      final user = User.fromRow(const {
        'uid': 'user-1',
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'ada@example.com',
        'photo_url': '',
      });

      expect(user.passwordHash, isNull);
    });

    test('defaults a null photo_url to an empty string', () {
      final user = User.fromRow(const {
        'uid': 'user-1',
        'first_name': 'Ada',
        'last_name': 'Lovelace',
        'email': 'ada@example.com',
        'photo_url': null,
      });

      expect(user.photoUrl, equals(''));
    });

    test('excludes the password hash from toJson', () {
      const user = User(
        uid: 'user-1',
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'ada@example.com',
        photoUrl: '',
        passwordHash: 'super-secret-digest',
      );

      expect(user.toJson().containsKey('password_hash'), isFalse);
      expect(user.toJson().toString(), isNot(contains('super-secret-digest')));
    });
  });

  group('Category', () {
    test('round-trips a row through toJson', () {
      const row = {
        'id': 1,
        'title_en': 'Burgers',
        'title_ru': 'Бургеры',
        'title_uz': 'Burgerlar',
        'icon': 'https://example.com/i.png',
      };

      expect(Category.fromRow(row).toJson(), equals(row));
    });

    test('tolerates a null icon', () {
      final category = Category.fromRow(const {
        'id': 1,
        'title_en': 'Burgers',
        'title_ru': 'Бургеры',
        'title_uz': 'Burgerlar',
        'icon': null,
      });

      expect(category.icon, isNull);
    });
  });

  group('Product', () {
    const row = {
      'id': 1,
      'restaurant_id': 2,
      'category': 3,
      'price': 25000.0,
      'status': 'available',
      'title_en': 'Classic Burger',
      'title_ru': null,
      'title_uz': null,
      'image': null,
      'description': null,
    };

    test('round-trips a row through toJson', () {
      expect(Product.fromRow(row).toJson(), equals(row));
    });

    // DOUBLE PRECISION arrives as a double, but an int-typed column would
    // arrive as an int and must not blow up the cast.
    test('widens an integer price to a double', () {
      final product = Product.fromRow({...row, 'price': 25000});
      expect(product.price, equals(25000.0));
      expect(product.price, isA<double>());
    });
  });

  group('Restaurant', () {
    const row = {
      'id': 1,
      'name': 'Burger House',
      'is_open': true,
      'rating': 4.5,
      'logo': null,
      'address': {'city': 'Tashkent'},
      'image': null,
      'cuisine': 1,
      'category': 1,
      'start_time': '09:00',
      'end_time': '23:00',
      'description': null,
      'phone_number': null,
      'delivery_cost': 5000.0,
      'min_delivery_time': 20,
      'max_delivery_time': 40,
      'free_delivery_from': 50000.0,
      'product_categories': [1],
    };

    test('round-trips a row through toJson', () {
      expect(Restaurant.fromRow(row).toJson(), equals(row));
    });

    // JSONB columns arrive decoded, not as JSON strings.
    test('reads address and product_categories as decoded JSON', () {
      final restaurant = Restaurant.fromRow(row);
      expect(restaurant.address, equals({'city': 'Tashkent'}));
      expect(restaurant.productCategories, equals([1]));
    });

    test('tolerates null nullable numerics', () {
      final restaurant = Restaurant.fromRow({
        ...row,
        'rating': null,
        'delivery_cost': null,
        'free_delivery_from': null,
        'product_categories': null,
      });

      expect(restaurant.rating, isNull);
      expect(restaurant.deliveryCost, isNull);
      expect(restaurant.productCategories, isNull);
    });
  });

  group('CartItem.tryParse', () {
    test('defaults a missing count to 1', () {
      expect(CartItem.tryParse(const {'id': 1})?.count, equals(1));
    });

    test('reads an explicit count', () {
      expect(CartItem.tryParse(const {'id': 1, 'count': 4})?.count, equals(4));
    });

    test('returns null for malformed entries', () {
      final malformed = <Object?>[
        null,
        42,
        'nope',
        <String, dynamic>{},
        {'id': '1'},
        {'id': 1.5},
        {'id': 1, 'count': 'two'},
        {'id': 1, 'count': 0},
        {'id': 1, 'count': -1},
      ];

      for (final value in malformed) {
        expect(
          CartItem.tryParse(value),
          isNull,
          reason: '$value should not parse',
        );
      }
    });
  });

  group('RefreshTokenRecord', () {
    final issuedAt = DateTime.utc(2026, 8, 15, 12);
    final expiresAt = DateTime.utc(2026, 8, 18, 12);
    final row = {
      'id': 'token-1',
      'user_id': 'user-1',
      'family_id': 'family-1',
      'issued_at': issuedAt,
      'expires_at': expiresAt,
      'revoked_at': null,
      'replaced_by': null,
    };

    test('reads a live token', () {
      final record = RefreshTokenRecord.fromRow(row);

      expect(record.id, equals('token-1'));
      expect(record.userId, equals('user-1'));
      expect(record.familyId, equals('family-1'));
      expect(record.issuedAt, equals(issuedAt));
      expect(record.expiresAt, equals(expiresAt));
      expect(record.isRevoked, isFalse);
      expect(record.replacedBy, isNull);
    });

    test('reads a rotated token', () {
      final record = RefreshTokenRecord.fromRow({
        ...row,
        'revoked_at': DateTime.utc(2026, 8, 15, 13),
        'replaced_by': 'token-2',
      });

      expect(record.isRevoked, isTrue);
      expect(record.revokedAt, equals(DateTime.utc(2026, 8, 15, 13)));
      expect(record.replacedBy, equals('token-2'));
    });

    test('is not expired before its expiry', () {
      final record = RefreshTokenRecord.fromRow(row);
      expect(
        record.hasExpired(expiresAt.subtract(const Duration(seconds: 1))),
        isFalse,
      );
    });

    test('is expired after its expiry', () {
      final record = RefreshTokenRecord.fromRow(row);
      expect(
        record.hasExpired(expiresAt.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    // The boundary is deliberate: a token is usable strictly before the
    // instant it expires, so an exactly-on-expiry token is refused.
    test('is expired exactly at its expiry', () {
      expect(RefreshTokenRecord.fromRow(row).hasExpired(expiresAt), isTrue);
    });
  });

  group('Order', () {
    final orderTime = DateTime.utc(2026, 8, 15, 12);
    final row = {
      'id': 'order-1',
      'user_id': 'user-1',
      'cost': 50000.0,
      'status': 'received',
      'order_time': orderTime,
      'restaurant_info': const {'id': 1, 'name': 'Burger House'},
      'products': const [
        {
          'id': 1,
          'price': 25000.0,
          'total': 50000.0,
          'count': 2,
          'status': 'available',
          'image': null,
          'title_en': 'Classic Burger',
          'title_ru': null,
          'title_uz': null,
          'category': 1,
          'sub_total': 50000.0,
          'description': null,
          'institution': 1,
        },
      ],
      'delivery_address': null,
      'courier': null,
      'payment_detail': null,
    };

    test('serialises order_time as ISO-8601', () {
      expect(
        Order.fromRow(row).toJson()['order_time'],
        equals('2026-08-15T12:00:00.000Z'),
      );
    });

    test('reads persisted line items back', () {
      final order = Order.fromRow(row);
      expect(order.products.single.count, equals(2));
      expect(order.products.single.subTotal, equals(50000.0));
    });

    // Orders created before user attribution existed have a null user_id and
    // must still read back rather than throwing.
    test('tolerates a legacy row with no user_id', () {
      final order = Order.fromRow({...row, 'user_id': null});
      expect(order.userId, isNull);
    });

    test('OrderProduct.from prices the line and records the restaurant', () {
      const product = Product(
        id: 7,
        restaurantId: 3,
        category: 1,
        price: 1500,
        status: 'available',
        titleEn: 'Fries',
        titleRu: null,
        titleUz: null,
        image: null,
        description: null,
      );

      final line = OrderProduct.from(product, 4);

      expect(line.subTotal, equals(6000));
      expect(line.toJson()['total'], equals(6000));
      expect(line.institution, equals(3));
    });
  });
}
