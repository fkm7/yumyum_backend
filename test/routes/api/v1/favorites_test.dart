import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/models/category.dart';
import 'package:delmer_backend/models/cuisine.dart';
import 'package:delmer_backend/models/product.dart';
import 'package:delmer_backend/models/restaurant.dart';
import 'package:delmer_backend/models/restaurant_category.dart';
import 'package:delmer_backend/repositories/favorite_repository.dart';
import 'package:delmer_backend/repositories/product_repository.dart';
import 'package:delmer_backend/repositories/restaurant_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../routes/api/v1/favorites/products/[id].dart'
    as favorite_product_by_id;
import '../../../../routes/api/v1/favorites/products/index.dart'
    as favorite_products;
import '../../../../routes/api/v1/favorites/restaurants/[id].dart'
    as favorite_restaurant_by_id;
import '../../../../routes/api/v1/favorites/restaurants/index.dart'
    as favorite_restaurants;
import '../../../helpers/test_context.dart';

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

const _restaurant = Restaurant(
  id: 1,
  name: 'Burger House',
  isOpen: true,
  rating: 4.5,
  logo: null,
  address: {'city': 'Tashkent'},
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
  productCategories: [_category],
);

const _product = Product(
  id: 1,
  restaurantId: 1,
  category: _category,
  price: 25000,
  status: 'available',
  titleEn: 'Classic Burger',
  titleRu: null,
  titleUz: null,
  image: null,
  description: null,
  unit: null,
);

void main() {
  setUpAll(() {
    registerFallbackValue(FavoriteType.restaurant);
  });

  group('GET /api/v1/favorites/restaurants', () {
    Future<Response> invoke(
      Request request, {
      List<int> ids = const [],
      List<Restaurant> found = const [],
    }) {
      final favorites = MockFavoriteRepository();
      when(() => favorites.findIds(any(), any())).thenAnswer((_) async => ids);
      final restaurants = MockRestaurantRepository();
      when(() => restaurants.findByIds(any())).thenAnswer((_) async => found);

      final context = TestContext(request: request)
        ..authenticateAs('user-1')
        ..provide<FavoriteRepository>(favorites)
        ..provide<RestaurantRepository>(restaurants);
      return Future.value(context.context).then(favorite_restaurants.onRequest);
    }

    test('rejects methods other than GET and POST', () async {
      await expectMethodNotAllowed(invoke, allowed: {'GET', 'POST'});
    });

    test('returns an empty array when there are no favorites', () async {
      final response = await invoke(jsonRequest('GET'));
      expect(response.statusCode, equals(200));
      expect(await jsonBody(response), isEmpty);
    });

    test('lists the favorited restaurants', () async {
      final response =
          await invoke(jsonRequest('GET'), ids: [1], found: [_restaurant]);
      expect(await jsonBody(response), equals([_restaurant.toJson()]));
    });

    test('scopes the lookup to the authenticated user', () async {
      final favorites = MockFavoriteRepository();
      when(() => favorites.findIds(any(), any())).thenAnswer((_) async => []);
      final restaurants = MockRestaurantRepository();
      when(() => restaurants.findByIds(any())).thenAnswer((_) async => []);
      final context = TestContext(request: jsonRequest('GET'))
        ..authenticateAs('user-42')
        ..provide<FavoriteRepository>(favorites)
        ..provide<RestaurantRepository>(restaurants);

      await favorite_restaurants.onRequest(context.context);

      verify(() => favorites.findIds('user-42', FavoriteType.restaurant))
          .called(1);
    });
  });

  group('POST /api/v1/favorites/restaurants', () {
    _Harness harness({Restaurant? restaurant = _restaurant}) {
      final favorites = MockFavoriteRepository();
      when(() => favorites.add(any(), any(), any())).thenAnswer((_) async {});
      final restaurants = MockRestaurantRepository();
      when(() => restaurants.findById(any()))
          .thenAnswer((_) async => restaurant);
      return _Harness(favorites: favorites, restaurants: restaurants);
    }

    TestContext context(_Harness h, Request request) {
      final context = TestContext(request: request)
        ..authenticateAs('user-1')
        ..provide<FavoriteRepository>(h.favorites)
        ..provide<RestaurantRepository>(h.restaurants);
      return context;
    }

    test('responds 400 for a malformed JSON body', () async {
      final h = harness();
      final response = await favorite_restaurants.onRequest(
        context(h, Request('POST', Uri.parse('http://localhost/'), body: '{'))
            .context,
      );
      expect(response.statusCode, equals(400));
    });

    test('responds 422 when restaurantId is missing or not an integer',
        () async {
      final h = harness();
      for (final body in [
        <String, dynamic>{},
        {'restaurantId': '1'},
      ]) {
        final response = await favorite_restaurants.onRequest(
          context(h, jsonRequest('POST', body: body)).context,
        );
        expect(response.statusCode, equals(422));
      }
    });

    test('responds 404 for an unknown restaurant', () async {
      final h = harness(restaurant: null);
      final response = await favorite_restaurants.onRequest(
        context(h, jsonRequest('POST', body: {'restaurantId': 1})).context,
      );
      expect(response.statusCode, equals(404));
      verifyNever(() => h.favorites.add(any(), any(), any()));
    });

    test('responds 201 and favorites the restaurant', () async {
      final h = harness();
      final response = await favorite_restaurants.onRequest(
        context(h, jsonRequest('POST', body: {'restaurantId': 1})).context,
      );

      expect(response.statusCode, equals(201));
      expect(await jsonBody(response), equals(_restaurant.toJson()));
      verify(() => h.favorites.add('user-1', FavoriteType.restaurant, 1))
          .called(1);
    });
  });

  group('DELETE /api/v1/favorites/restaurants/[id]', () {
    Future<Response> invoke(
      Request request,
      String id, {
      MockFavoriteRepository? favorites,
    }) {
      final repository = favorites ?? MockFavoriteRepository();
      when(() => repository.remove(any(), any(), any()))
          .thenAnswer((_) async {});
      final context = TestContext(request: request)
        ..authenticateAs('user-1')
        ..provide<FavoriteRepository>(repository);
      return Future.value(context.context)
          .then((c) => favorite_restaurant_by_id.onRequest(c, id));
    }

    test('rejects every method except DELETE', () async {
      await expectMethodNotAllowed(
        (request) => invoke(request, '1'),
        allowed: {'DELETE'},
      );
    });

    test('responds 400 for a non-numeric id', () async {
      expect(
        (await invoke(jsonRequest('DELETE'), 'abc')).statusCode,
        equals(400),
      );
    });

    test('responds 204 and unfavorites the restaurant', () async {
      final favorites = MockFavoriteRepository();
      final response =
          await invoke(jsonRequest('DELETE'), '1', favorites: favorites);

      expect(response.statusCode, equals(204));
      verify(() => favorites.remove('user-1', FavoriteType.restaurant, 1))
          .called(1);
    });
  });

  group('GET /api/v1/favorites/products', () {
    Future<Response> invoke(
      Request request, {
      List<int> ids = const [],
      List<Product> found = const [],
    }) {
      final favorites = MockFavoriteRepository();
      when(() => favorites.findIds(any(), any())).thenAnswer((_) async => ids);
      final products = MockProductRepository();
      when(() => products.findByIds(any())).thenAnswer((_) async => found);

      final context = TestContext(request: request)
        ..authenticateAs('user-1')
        ..provide<FavoriteRepository>(favorites)
        ..provide<ProductRepository>(products);
      return Future.value(context.context).then(favorite_products.onRequest);
    }

    test('rejects methods other than GET and POST', () async {
      await expectMethodNotAllowed(invoke, allowed: {'GET', 'POST'});
    });

    test('lists the favorited products', () async {
      final response =
          await invoke(jsonRequest('GET'), ids: [1], found: [_product]);
      expect(await jsonBody(response), equals([_product.toJson()]));
    });
  });

  group('POST /api/v1/favorites/products', () {
    _ProductHarness harness({Product? product = _product}) {
      final favorites = MockFavoriteRepository();
      when(() => favorites.add(any(), any(), any())).thenAnswer((_) async {});
      final products = MockProductRepository();
      when(() => products.findById(any())).thenAnswer((_) async => product);
      return _ProductHarness(favorites: favorites, products: products);
    }

    TestContext context(_ProductHarness h, Request request) {
      final context = TestContext(request: request)
        ..authenticateAs('user-1')
        ..provide<FavoriteRepository>(h.favorites)
        ..provide<ProductRepository>(h.products);
      return context;
    }

    test('responds 422 when productId is missing or not an integer', () async {
      final h = harness();
      final response = await favorite_products.onRequest(
        context(h, jsonRequest('POST', body: <String, dynamic>{})).context,
      );
      expect(response.statusCode, equals(422));
    });

    test('responds 404 for an unknown product', () async {
      final h = harness(product: null);
      final response = await favorite_products.onRequest(
        context(h, jsonRequest('POST', body: {'productId': 1})).context,
      );
      expect(response.statusCode, equals(404));
      verifyNever(() => h.favorites.add(any(), any(), any()));
    });

    test('responds 201 and favorites the product', () async {
      final h = harness();
      final response = await favorite_products.onRequest(
        context(h, jsonRequest('POST', body: {'productId': 1})).context,
      );

      expect(response.statusCode, equals(201));
      expect(await jsonBody(response), equals(_product.toJson()));
      verify(() => h.favorites.add('user-1', FavoriteType.product, 1))
          .called(1);
    });
  });

  group('DELETE /api/v1/favorites/products/[id]', () {
    Future<Response> invoke(
      Request request,
      String id, {
      MockFavoriteRepository? favorites,
    }) {
      final repository = favorites ?? MockFavoriteRepository();
      when(() => repository.remove(any(), any(), any()))
          .thenAnswer((_) async {});
      final context = TestContext(request: request)
        ..authenticateAs('user-1')
        ..provide<FavoriteRepository>(repository);
      return Future.value(context.context)
          .then((c) => favorite_product_by_id.onRequest(c, id));
    }

    test('rejects every method except DELETE', () async {
      await expectMethodNotAllowed(
        (request) => invoke(request, '1'),
        allowed: {'DELETE'},
      );
    });

    test('responds 400 for a non-numeric id', () async {
      expect(
        (await invoke(jsonRequest('DELETE'), 'abc')).statusCode,
        equals(400),
      );
    });

    test('responds 204 and unfavorites the product', () async {
      final favorites = MockFavoriteRepository();
      final response =
          await invoke(jsonRequest('DELETE'), '1', favorites: favorites);

      expect(response.statusCode, equals(204));
      verify(() => favorites.remove('user-1', FavoriteType.product, 1))
          .called(1);
    });
  });
}

class _Harness {
  _Harness({required this.favorites, required this.restaurants});
  final MockFavoriteRepository favorites;
  final MockRestaurantRepository restaurants;
}

class _ProductHarness {
  _ProductHarness({required this.favorites, required this.products});
  final MockFavoriteRepository favorites;
  final MockProductRepository products;
}
