@Tags(['integration'])
library;

import 'package:delmer_backend/auth/bcrypt_password_hasher.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:delmer_backend/models/category.dart';
import 'package:delmer_backend/models/order.dart';
import 'package:delmer_backend/models/refresh_token_record.dart';
import 'package:delmer_backend/repositories/favorite_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_category_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_cuisine_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_favorite_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_order_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_product_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_refresh_token_repository.dart';
import 'package:delmer_backend/repositories/postgres/postgres_restaurant_category_repository.dart';
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
  final cuisines = PostgresCuisineRepository(database);
  final restaurantCategories = PostgresRestaurantCategoryRepository(database);
  final restaurants = PostgresRestaurantRepository(database);
  final products = PostgresProductRepository(database);
  final users = PostgresUserRepository(database);
  final orders = PostgresOrderRepository(database);
  final favorites = PostgresFavoriteRepository(database);
  final refreshTokens = PostgresRefreshTokenRepository(database);

  var counter = 0;
  String uniqueEmail() => 'test-${DateTime.now().microsecondsSinceEpoch}'
      '-${counter++}@example.com';

  tearDownAll(() async {
    final conn = await database.connection;
    await conn.execute("DELETE FROM orders WHERE id LIKE 'itest-%'");
    await conn.execute(
      'DELETE FROM refresh_tokens WHERE user_id IN '
      "(SELECT uid FROM users WHERE email LIKE 'test-%@example.com')",
    );
    await conn.execute(
      'DELETE FROM favorites WHERE user_id IN '
      "(SELECT uid FROM users WHERE email LIKE 'test-%@example.com')",
    );
    await conn
        .execute("DELETE FROM users WHERE email LIKE 'test-%@example.com'");
    await conn.close();
  });

  group('CategoryRepository', () {
    test('reads the seeded categories', () async {
      final all = await categories.findAll();

      expect(all, isNotEmpty);
      expect(all.map((c) => c.titleEn), contains('Second course'));
      expect(all.first.id, isA<int>());
    });
  });

  group('CuisineRepository', () {
    test('reads the seeded cuisines', () async {
      final all = await cuisines.findAll();

      expect(all, isNotEmpty);
      expect(all.map((c) => c.titleEn), contains('Italian'));
      expect(all.first.id, isA<int>());
    });
  });

  group('RestaurantCategoryRepository', () {
    test('reads the seeded restaurant categories', () async {
      final all = await restaurantCategories.findAll();

      expect(all, isNotEmpty);
      expect(all.map((c) => c.titleEn), contains('Sushi'));
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
      expect(restaurant.productCategories, isA<List<Category>>());
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

    test('filters by cuisine', () async {
      final filtered = await restaurants.findByCuisine(2);

      expect(filtered, isNotEmpty);
      expect(filtered.every((r) => r.cuisine.id == 2), isTrue);
    });

    test('returns an empty list for a cuisine with no restaurants', () async {
      expect(await restaurants.findByCuisine(999999), isEmpty);
    });

    test('filters by restaurant category', () async {
      final filtered = await restaurants.findByCategory(2);

      expect(filtered, isNotEmpty);
      expect(filtered.every((r) => r.category.id == 2), isTrue);
    });

    test('returns an empty list for a category with no restaurants', () async {
      expect(await restaurants.findByCategory(999999), isEmpty);
    });

    // findByIds uses `= ANY(@ids)` with a typed int array, which only a real
    // server can validate.
    test('finds several restaurants in one round trip', () async {
      final found = await restaurants.findByIds([1, 2, 3]);
      expect(found.map((r) => r.id).toSet(), equals({1, 2, 3}));
    });

    test('silently omits ids that do not exist', () async {
      final found = await restaurants.findByIds([1, 999999]);
      expect(found.map((r) => r.id), equals([1]));
    });

    test('returns an empty list for no ids without querying', () async {
      expect(await restaurants.findByIds([]), isEmpty);
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

  group('FavoriteRepository', () {
    late String userId;

    setUpAll(() async {
      final user = await users.create(
        firstName: 'Favorite',
        lastName: 'Owner',
        email: uniqueEmail(),
        passwordHash: 'digest',
      );
      userId = user!.uid;
    });

    test('adds and lists a favorite', () async {
      await favorites.add(userId, FavoriteType.restaurant, 1);
      expect(
        await favorites.findIds(userId, FavoriteType.restaurant),
        contains(1),
      );
    });

    test('adding the same favorite twice is a no-op', () async {
      await favorites.add(userId, FavoriteType.restaurant, 2);
      await favorites.add(userId, FavoriteType.restaurant, 2);

      final ids = await favorites.findIds(userId, FavoriteType.restaurant);
      expect(ids.where((id) => id == 2), hasLength(1));
    });

    test('keeps restaurant and product favorites separate', () async {
      await favorites.add(userId, FavoriteType.restaurant, 3);
      await favorites.add(userId, FavoriteType.product, 3);

      expect(
        await favorites.findIds(userId, FavoriteType.restaurant),
        contains(3),
      );
      expect(
        await favorites.findIds(userId, FavoriteType.product),
        contains(3),
      );
    });

    test('removes a favorite', () async {
      await favorites.add(userId, FavoriteType.product, 4);
      await favorites.remove(userId, FavoriteType.product, 4);

      expect(
        await favorites.findIds(userId, FavoriteType.product),
        isNot(contains(4)),
      );
    });

    test('removing an unfavorited item is a no-op', () async {
      await expectLater(
        favorites.remove(userId, FavoriteType.product, 999999),
        completes,
      );
    });

    test('lists most recently favorited first', () async {
      final other = (await users.create(
        firstName: 'Recency',
        lastName: 'Owner',
        email: uniqueEmail(),
        passwordHash: 'digest',
      ))!
          .uid;

      await favorites.add(other, FavoriteType.restaurant, 4);
      await favorites.add(other, FavoriteType.restaurant, 5);

      final ids = await favorites.findIds(other, FavoriteType.restaurant);
      expect(ids, equals([5, 4]));
    });

    test("does not leak another user's favorites", () async {
      final other = (await users.create(
        firstName: 'Someone',
        lastName: 'Else',
        email: uniqueEmail(),
        passwordHash: 'digest',
      ))!
          .uid;

      await favorites.add(other, FavoriteType.restaurant, 6);

      expect(
        await favorites.findIds(userId, FavoriteType.restaurant),
        isNot(contains(6)),
      );
    });
  });

  group('RefreshTokenRepository', () {
    late String userId;
    final issuedAt = DateTime.utc(2026, 8, 15, 12);

    setUpAll(() async {
      final user = await users.create(
        firstName: 'Token',
        lastName: 'Owner',
        email: uniqueEmail(),
        passwordHash: 'digest',
      );
      userId = user!.uid;
    });

    RefreshTokenRecord record({
      required String id,
      String? familyId,
      DateTime? expiresAt,
    }) =>
        RefreshTokenRecord(
          id: id,
          userId: userId,
          familyId: familyId ?? 'family-$id',
          issuedAt: issuedAt,
          expiresAt: expiresAt ?? issuedAt.add(const Duration(days: 3)),
        );

    String uniqueId() =>
        'itest-token-${DateTime.now().microsecondsSinceEpoch}-${counter++}';

    test('round-trips an issued token', () async {
      final id = uniqueId();
      await refreshTokens.issue(record(id: id));

      final found = await refreshTokens.findById(id);

      expect(found, isNotNull);
      expect(found!.userId, equals(userId));
      expect(found.familyId, equals('family-$id'));
      expect(found.isRevoked, isFalse);
      expect(found.replacedBy, isNull);
    });

    // TIMESTAMPTZ must come back as a DateTime, or expiry comparison throws.
    test('reads timestamps back as DateTimes', () async {
      final id = uniqueId();
      await refreshTokens.issue(record(id: id));

      final found = await refreshTokens.findById(id);

      expect(found!.issuedAt, isA<DateTime>());
      expect(found.issuedAt.toUtc(), equals(issuedAt));
      expect(
        found.expiresAt.toUtc(),
        equals(issuedAt.add(const Duration(days: 3))),
      );
    });

    test('returns null for an unknown id', () async {
      expect(await refreshTokens.findById('no-such-token'), isNull);
    });

    test('revokes a token and records its successor', () async {
      final id = uniqueId();
      final successor = uniqueId();
      await refreshTokens.issue(record(id: id));

      final revokedAt = DateTime.utc(2026, 8, 15, 13);
      await refreshTokens.revoke(
        id,
        revokedAt: revokedAt,
        replacedBy: successor,
      );

      final found = await refreshTokens.findById(id);
      expect(found!.isRevoked, isTrue);
      expect(found.revokedAt!.toUtc(), equals(revokedAt));
      expect(found.replacedBy, equals(successor));
    });

    // Revoking twice must not move the original timestamp forward.
    test('keeps the first revocation timestamp', () async {
      final id = uniqueId();
      await refreshTokens.issue(record(id: id));

      final first = DateTime.utc(2026, 8, 15, 13);
      await refreshTokens.revoke(id, revokedAt: first);
      await refreshTokens.revoke(id, revokedAt: DateTime.utc(2026, 8, 15, 14));

      final found = await refreshTokens.findById(id);
      expect(found!.revokedAt!.toUtc(), equals(first));
    });

    test('revoking an unknown token is a no-op', () async {
      await expectLater(
        refreshTokens.revoke('no-such-token', revokedAt: issuedAt),
        completes,
      );
    });

    test('revokes an entire family in one statement', () async {
      final family = 'itest-family-${DateTime.now().microsecondsSinceEpoch}';
      final ids = [uniqueId(), uniqueId(), uniqueId()];
      for (final id in ids) {
        await refreshTokens.issue(record(id: id, familyId: family));
      }

      await refreshTokens.revokeFamily(
        family,
        revokedAt: DateTime.utc(2026, 8, 15, 13),
      );

      for (final id in ids) {
        expect((await refreshTokens.findById(id))!.isRevoked, isTrue);
      }
    });

    test('leaves other families untouched', () async {
      final mine = uniqueId();
      final theirs = uniqueId();
      await refreshTokens.issue(record(id: mine, familyId: 'family-a'));
      await refreshTokens.issue(record(id: theirs, familyId: 'family-b'));

      await refreshTokens.revokeFamily('family-a', revokedAt: issuedAt);

      expect((await refreshTokens.findById(theirs))!.isRevoked, isFalse);
    });

    test('prunes expired tokens and leaves live ones', () async {
      final expired = uniqueId();
      final live = uniqueId();
      await refreshTokens.issue(
        record(id: expired, expiresAt: DateTime.utc(2020)),
      );
      await refreshTokens.issue(
        record(id: live, expiresAt: DateTime.utc(2099)),
      );

      final removed = await refreshTokens.deleteExpired(DateTime.utc(2026));

      expect(removed, greaterThanOrEqualTo(1));
      expect(await refreshTokens.findById(expired), isNull);
      expect(await refreshTokens.findById(live), isNotNull);
    });

    // ON DELETE CASCADE: removing a user must not leave orphan tokens behind.
    test("drops a user's tokens when the user is deleted", () async {
      final doomed = await users.create(
        firstName: 'Soon',
        lastName: 'Gone',
        email: uniqueEmail(),
        passwordHash: 'digest',
      );
      final id = uniqueId();
      await refreshTokens.issue(
        RefreshTokenRecord(
          id: id,
          userId: doomed!.uid,
          familyId: 'family-doomed',
          issuedAt: issuedAt,
          expiresAt: issuedAt.add(const Duration(days: 3)),
        ),
      );

      final conn = await database.connection;
      await conn.execute(
        Sql.named('DELETE FROM users WHERE uid = @uid'),
        parameters: {'uid': doomed.uid},
      );

      expect(await refreshTokens.findById(id), isNull);
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
