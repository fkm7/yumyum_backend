@Tags(['integration'])
library;

import 'package:delmer_backend/auth/bcrypt_password_hasher.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:delmer_backend/models/order.dart';
import 'package:delmer_backend/repositories/postgres/postgres_category_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_order_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_product_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_restaurant_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_user_repository.dart';
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

/// These run against a real PostgreSQL seeded from `lib/db/schema.sql`
/// (`docker compose up -d`). They exist to verify the things a mocked
/// repository can never catch: column names, and how the driver maps
/// PostgreSQL types onto Dart ones.
void main() {
  final database = DatabaseService.instance;
  final categories = PostgresCategoryRepository(database);
  final restaurants = PostgresRestaurantRepository(database);
  final products = PostgresProductRepository(database);
  final users = PostgresUserRepository(database);
  final orders = PostgresOrderRepository(database);

  var counter = 0;
  String uniqueEmail() => 'test-${DateTime.now().microsecondsSinceEpoch}'
      '-${counter++}@example.com';

  tearDownAll(() async {
    final conn = await database.connection;
    await conn.execute("DELETE FROM orders WHERE id LIKE 'itest-%'");
    await conn
        .execute("DELETE FROM users WHERE email LIKE 'test-%@example.com'");
    await conn.close();
  });

  group('CategoryRepository', () {
    test('reads the seeded categories', () async {
      final all = await categories.findAll();

      expect(all, isNotEmpty);
      expect(all.map((c) => c.titleEn), contains('Burgers'));
      expect(all.first.id, isA<int>());
    });
  });

  group('RestaurantRepository', () {
    test('reads every column the model expects', () async {
      final all = await restaurants.findAll();
      expect(all, isNotEmpty);
    });

    // JSONB columns come back already decoded. If the driver returned strings
    // instead, `row['address'] as Map` would throw here and nowhere else.
    test('decodes JSONB columns into Dart collections', () async {
      final restaurant = await restaurants.findById(1);

      expect(restaurant, isNotNull);
      expect(restaurant!.address, isA<Map<String, dynamic>>());
      expect(restaurant.address['city'], equals('Tashkent'));
      expect(restaurant.productCategories, isA<List<dynamic>>());
    });

    test('maps DOUBLE PRECISION onto double', () async {
      final restaurant = await restaurants.findById(1);
      expect(restaurant!.rating, isA<double>());
      expect(restaurant.deliveryCost, isA<double>());
    });

    test('maps BOOLEAN onto bool', () async {
      final restaurant = await restaurants.findById(3);
      expect(restaurant!.isOpen, isFalse);
    });

    test('returns null for an unknown id', () async {
      expect(await restaurants.findById(999999), isNull);
    });

    test('filters by category', () async {
      final filtered = await restaurants.findByCategory(2);

      expect(filtered, isNotEmpty);
      expect(filtered.every((r) => r.category == 2), isTrue);
    });

    test('returns an empty list for a category with no restaurants', () async {
      expect(await restaurants.findByCategory(999999), isEmpty);
    });
  });

  group('ProductRepository', () {
    test('reads every column the model expects', () async {
      final all = await products.findAll();
      expect(all, isNotEmpty);
      expect(all.first.price, isA<double>());
    });

    test('finds a product by id', () async {
      final product = await products.findById(1);
      expect(product!.titleEn, equals('Classic Burger'));
      expect(product.restaurantId, equals(1));
    });

    test('returns null for an unknown id', () async {
      expect(await products.findById(999999), isNull);
    });

    test('finds products by restaurant', () async {
      final found = await products.findByRestaurant(1);

      expect(found, isNotEmpty);
      expect(found.every((p) => p.restaurantId == 1), isTrue);
    });

    // findByIds uses `= ANY(@ids)` with a typed int array, which only a real
    // server can validate.
    test('finds several products in one round trip', () async {
      final found = await products.findByIds([1, 2, 3]);

      expect(found.map((p) => p.id).toSet(), equals({1, 2, 3}));
    });

    test('silently omits ids that do not exist', () async {
      final found = await products.findByIds([1, 999999]);
      expect(found.map((p) => p.id), equals([1]));
    });

    test('returns an empty list for no ids without querying', () async {
      expect(await products.findByIds([]), isEmpty);
    });
  });

  group('UserRepository', () {
    test('creates a user and reads it back', () async {
      final email = uniqueEmail();
      final created = await users.create(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: email,
        passwordHash: 'digest',
      );

      expect(created, isNotNull);
      expect(created!.email, equals(email));
      expect(created.uid, isNotEmpty);

      final found = await users.findByUid(created.uid);
      expect(found!.firstName, equals('Ada'));
    });

    test('assigns a uid that is not a timestamp', () async {
      final created = await users.create(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: uniqueEmail(),
        passwordHash: 'digest',
      );

      expect(int.tryParse(created!.uid), isNull);
      expect(created.uid, hasLength(36));
    });

    // The unique index is what enforces this, so it is only really proven
    // against a live server.
    test('returns null rather than throwing on a duplicate email', () async {
      final email = uniqueEmail();
      final first = await users.create(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: email,
        passwordHash: 'digest',
      );
      final second = await users.create(
        firstName: 'Someone',
        lastName: 'Else',
        email: email,
        passwordHash: 'other-digest',
      );

      expect(first, isNotNull);
      expect(second, isNull);
    });

    test('findByEmail carries the password hash', () async {
      final email = uniqueEmail();
      await users.create(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: email,
        passwordHash: 'digest',
      );

      final found = await users.findByEmail(email);
      expect(found!.passwordHash, equals('digest'));
    });

    // /auth/me does not select the column, so the model has to cope with it
    // being absent from the row.
    test('findByUid omits the password hash', () async {
      final created = await users.create(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: uniqueEmail(),
        passwordHash: 'digest',
      );

      final found = await users.findByUid(created!.uid);
      expect(found!.passwordHash, isNull);
    });

    test('returns null for an unknown email and uid', () async {
      expect(await users.findByEmail('nobody@example.com'), isNull);
      expect(await users.findByUid('no-such-uid'), isNull);
    });

    test('updates the stored password digest', () async {
      final email = uniqueEmail();
      final created = await users.create(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: email,
        passwordHash: 'old-digest',
      );

      await users.updatePasswordHash(created!.uid, 'new-digest');

      final found = await users.findByEmail(email);
      expect(found!.passwordHash, equals('new-digest'));
    });

    test('updating an unknown uid is a no-op rather than an error', () async {
      await expectLater(
        users.updatePasswordHash('no-such-uid', 'digest'),
        completes,
      );
    });

    // The migration end to end: a row stored under the old scheme verifies,
    // gets rewritten as bcrypt, and still verifies afterwards. bcrypt digests
    // are 60 characters, so this also proves the column is wide enough.
    test('migrates a legacy digest to bcrypt and back out again', () async {
      final hasher = BcryptPasswordHasher(rounds: 4);
      final email = uniqueEmail();
      final created = await users.create(
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: email,
        passwordHash: legacySha256Digest('hunter2'),
      );

      final legacy = await users.findByEmail(email);
      expect(hasher.verify('hunter2', legacy!.passwordHash!), isTrue);
      expect(hasher.needsRehash(legacy.passwordHash!), isTrue);

      await users.updatePasswordHash(created!.uid, hasher.hash('hunter2'));

      final upgraded = await users.findByEmail(email);
      expect(upgraded!.passwordHash, startsWith(r'$2a$'));
      expect(upgraded.passwordHash, hasLength(60));
      expect(hasher.verify('hunter2', upgraded.passwordHash!), isTrue);
      expect(hasher.verify('wrong', upgraded.passwordHash!), isFalse);
      expect(hasher.needsRehash(upgraded.passwordHash!), isFalse);
    });
  });

  group('OrderRepository', () {
    Future<Order> place(String userId, {String? id}) async {
      final product = (await products.findById(1))!;
      return orders.create(
        Order(
          id: id ?? 'itest-${DateTime.now().microsecondsSinceEpoch}-$counter',
          userId: userId,
          cost: product.price * 2,
          status: 'received',
          orderTime: DateTime.utc(2026, 8, 15, 12),
          restaurantInfo: (await restaurants.findById(1))!.toJson(),
          products: [OrderProduct.from(product, 2)],
          deliveryAddress: const {'street': '1 Test Way', 'city': 'Tashkent'},
          courier: null,
          paymentDetail: null,
        ),
      );
    }

    late String userId;

    setUpAll(() async {
      final user = await users.create(
        firstName: 'Order',
        lastName: 'Owner',
        email: uniqueEmail(),
        passwordHash: 'digest',
      );
      userId = user!.uid;
    });

    test('round-trips an order through JSONB', () async {
      final placed = await place(userId);
      final found = await orders.findById(placed.id);

      expect(found, isNotNull);
      expect(found!.cost, equals(placed.cost));
      expect(found.status, equals('received'));
      expect(found.userId, equals(userId));
    });

    // TIMESTAMPTZ must come back as a DateTime for Order.toJson to serialise
    // it; a String here would throw.
    test('reads order_time back as a DateTime', () async {
      final placed = await place(userId);
      final found = await orders.findById(placed.id);

      expect(found!.orderTime, isA<DateTime>());
      expect(found.orderTime.toUtc(), equals(DateTime.utc(2026, 8, 15, 12)));
    });

    test('reads persisted line items back into OrderProduct', () async {
      final placed = await place(userId);
      final found = await orders.findById(placed.id);

      final line = found!.products.single;
      expect(line.id, equals(1));
      expect(line.count, equals(2));
      expect(line.subTotal, equals(line.price * 2));
      expect(line.institution, equals(1));
    });

    test('reads the delivery address back as a map', () async {
      final placed = await place(userId);
      final found = await orders.findById(placed.id);

      expect(found!.deliveryAddress, isA<Map<String, dynamic>>());
      expect(found.deliveryAddress!['city'], equals('Tashkent'));
    });

    test('leaves a null delivery address null', () async {
      final product = (await products.findById(1))!;
      final placed = await orders.create(
        Order(
          id: 'itest-null-address-${DateTime.now().microsecondsSinceEpoch}',
          userId: userId,
          cost: product.price,
          status: 'received',
          orderTime: DateTime.utc(2026, 8, 15, 12),
          restaurantInfo: (await restaurants.findById(1))!.toJson(),
          products: [OrderProduct.from(product, 1)],
          deliveryAddress: null,
          courier: null,
          paymentDetail: null,
        ),
      );

      final found = await orders.findById(placed.id);
      expect(found!.deliveryAddress, isNull);
      expect(found.courier, isNull);
    });

    // The listing must be scoped by owner; this is the query behind the
    // route-level authorisation.
    test("lists only the given user's orders", () async {
      final other = await users.create(
        firstName: 'Someone',
        lastName: 'Else',
        email: uniqueEmail(),
        passwordHash: 'digest',
      );

      await place(userId);
      await place(other!.uid);

      final mine = await orders.findByUser(userId);
      final theirs = await orders.findByUser(other.uid);

      expect(mine, isNotEmpty);
      expect(mine.every((o) => o.userId == userId), isTrue);
      expect(theirs.every((o) => o.userId == other.uid), isTrue);
      expect(
        mine.map((o) => o.id).toSet().intersection(
              theirs.map((o) => o.id).toSet(),
            ),
        isEmpty,
      );
    });

    test('returns null for an unknown order id', () async {
      expect(await orders.findById('no-such-order'), isNull);
    });
  });

  group('schema', () {
    test('enforces a unique email', () async {
      final conn = await database.connection;
      final result = await conn.execute(
        Sql.named('''
          SELECT indexdef FROM pg_indexes
          WHERE tablename = 'users' AND indexdef LIKE '%email%'
        '''),
      );
      expect(result, isNotEmpty);
    });

    test('indexes orders by user for the listing query', () async {
      final conn = await database.connection;
      final result = await conn.execute(
        Sql.named('''
          SELECT indexname FROM pg_indexes
          WHERE tablename = 'orders' AND indexname = @name
        '''),
        parameters: {'name': 'orders_user_id_order_time_idx'},
      );
      expect(result, isNotEmpty);
    });
  });
}
