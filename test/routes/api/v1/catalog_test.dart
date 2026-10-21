import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import 'package:yumyum_backend/models/category.dart';
import 'package:yumyum_backend/models/cuisine.dart';
import 'package:yumyum_backend/models/product.dart';
import 'package:yumyum_backend/models/restaurant.dart';
import 'package:yumyum_backend/models/restaurant_category.dart';
import 'package:yumyum_backend/repositories/category_repository.dart';
import 'package:yumyum_backend/repositories/cuisine_repository.dart';
import 'package:yumyum_backend/repositories/product_repository.dart';
import 'package:yumyum_backend/repositories/restaurant_category_repository.dart';
import 'package:yumyum_backend/repositories/restaurant_repository.dart';

import '../../../../routes/api/v1/categories/index.dart' as categories;
import '../../../../routes/api/v1/cuisines/index.dart' as cuisines;
import '../../../../routes/api/v1/products/[id].dart' as product_by_id;
import '../../../../routes/api/v1/products/index.dart' as products;
import '../../../../routes/api/v1/restaurant-categories/index.dart'
    as restaurant_categories;
import '../../../../routes/api/v1/restaurants/[id]/index.dart'
    as restaurant_by_id;
import '../../../../routes/api/v1/restaurants/[id]/products.dart'
    as restaurant_products;
import '../../../../routes/api/v1/restaurants/index.dart' as restaurants;
import '../../../helpers/test_context.dart';

const _category = Category(
  id: 1,
  titleEn: 'Burgers',
  titleRu: 'Бургеры',
  titleUz: 'Burgerlar',
  icon: 'https://example.com/burgers.png',
);

const _cuisine = Cuisine(
  id: 1,
  titleEn: 'American',
  titleRu: 'Американская',
  titleUz: 'Amerika oshxonasi',
  icon: 'https://example.com/american.png',
);

const _restaurantCategory = RestaurantCategory(
  id: 1,
  titleEn: 'Burgers',
  titleRu: 'Бургеры',
  titleUz: 'Burgerlar',
  icon: 'https://example.com/burgers.png',
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

void main() {
  group('GET /api/v1/categories', () {
    Future<Response> invoke(
      Request request, {
      List<Category> found = const [],
    }) {
      final repository = MockCategoryRepository();
      when(repository.findAll).thenAnswer((_) async => found);
      final context = TestContext(request: request)
        ..provide<CategoryRepository>(repository);
      return Future.value(context.context).then(categories.onRequest);
    }

    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(invoke, allowed: {'GET'});
    });

    test('returns an empty array when there are none', () async {
      final response = await invoke(jsonRequest('GET'));
      expect(response.statusCode, equals(200));
      expect(await jsonBody(response), isEmpty);
    });

    test('serialises categories in snake_case', () async {
      final response = await invoke(jsonRequest('GET'), found: [_category]);
      expect(await jsonBody(response), equals([_category.toJson()]));
    });
  });

  group('GET /api/v1/cuisines', () {
    Future<Response> invoke(
      Request request, {
      List<Cuisine> found = const [],
    }) {
      final repository = MockCuisineRepository();
      when(repository.findAll).thenAnswer((_) async => found);
      final context = TestContext(request: request)
        ..provide<CuisineRepository>(repository);
      return Future.value(context.context).then(cuisines.onRequest);
    }

    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(invoke, allowed: {'GET'});
    });

    test('returns an empty array when there are none', () async {
      final response = await invoke(jsonRequest('GET'));
      expect(response.statusCode, equals(200));
      expect(await jsonBody(response), isEmpty);
    });

    test('serialises cuisines in snake_case', () async {
      final response = await invoke(jsonRequest('GET'), found: [_cuisine]);
      expect(await jsonBody(response), equals([_cuisine.toJson()]));
    });
  });

  group('GET /api/v1/restaurant-categories', () {
    Future<Response> invoke(
      Request request, {
      List<RestaurantCategory> found = const [],
    }) {
      final repository = MockRestaurantCategoryRepository();
      when(repository.findAll).thenAnswer((_) async => found);
      final context = TestContext(request: request)
        ..provide<RestaurantCategoryRepository>(repository);
      return Future.value(context.context)
          .then(restaurant_categories.onRequest);
    }

    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(invoke, allowed: {'GET'});
    });

    test('returns an empty array when there are none', () async {
      final response = await invoke(jsonRequest('GET'));
      expect(response.statusCode, equals(200));
      expect(await jsonBody(response), isEmpty);
    });

    test('serialises restaurant categories in snake_case', () async {
      final response =
          await invoke(jsonRequest('GET'), found: [_restaurantCategory]);
      expect(await jsonBody(response), equals([_restaurantCategory.toJson()]));
    });
  });

  group('GET /api/v1/products', () {
    Future<Response> invoke(Request request, {List<Product> found = const []}) {
      final repository = MockProductRepository();
      when(repository.findAll).thenAnswer((_) async => found);
      final context = TestContext(request: request)
        ..provide<ProductRepository>(repository);
      return Future.value(context.context).then(products.onRequest);
    }

    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(invoke, allowed: {'GET'});
    });

    test('serialises products in snake_case', () async {
      final response = await invoke(jsonRequest('GET'), found: [_product]);
      expect(await jsonBody(response), equals([_product.toJson()]));
    });
  });

  group('GET /api/v1/products/[id]', () {
    Future<Response> invoke(Request request, String id, {Product? found}) {
      final repository = MockProductRepository();
      when(() => repository.findById(any())).thenAnswer((_) async => found);
      final context = TestContext(request: request)
        ..provide<ProductRepository>(repository);
      return Future.value(context.context)
          .then((c) => product_by_id.onRequest(c, id));
    }

    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(
        (request) => invoke(request, '1', found: _product),
        allowed: {'GET'},
      );
    });

    // This route used to pass the raw path segment into a query against an
    // INTEGER primary key, so a non-numeric id produced a 500.
    test('responds 400 for a non-numeric id', () async {
      for (final id in ['abc', '', '1.5', '٣']) {
        final response = await invoke(jsonRequest('GET'), id);
        expect(
          response.statusCode,
          equals(400),
          reason: 'id "$id" should be rejected',
        );
      }
    });

    test('responds 404 for an unknown id', () async {
      final response = await invoke(jsonRequest('GET'), '999');
      expect(response.statusCode, equals(404));
    });

    test('responds 200 with the product', () async {
      final response = await invoke(jsonRequest('GET'), '1', found: _product);
      expect(response.statusCode, equals(200));
      expect(await jsonBody(response), equals(_product.toJson()));
    });

    test('parses the id before querying', () async {
      final repository = MockProductRepository();
      when(() => repository.findById(any())).thenAnswer((_) async => _product);
      final context = TestContext(request: jsonRequest('GET'))
        ..provide<ProductRepository>(repository);

      await product_by_id.onRequest(context.context, '42');

      verify(() => repository.findById(42)).called(1);
    });
  });

  group('GET /api/v1/restaurants', () {
    Future<Response> invoke(
      Request request, {
      List<Restaurant> all = const [],
      List<Restaurant> byCuisine = const [],
      List<Restaurant> byCategory = const [],
    }) {
      final repository = MockRestaurantRepository();
      when(repository.findAll).thenAnswer((_) async => all);
      when(() => repository.findByCuisine(any()))
          .thenAnswer((_) async => byCuisine);
      when(() => repository.findByCategory(any()))
          .thenAnswer((_) async => byCategory);
      final context = TestContext(request: request)
        ..provide<RestaurantRepository>(repository);
      return Future.value(context.context).then(restaurants.onRequest);
    }

    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(invoke, allowed: {'GET'});
    });

    test('returns every restaurant when no filter is given', () async {
      final response = await invoke(jsonRequest('GET'), all: [_restaurant]);
      expect(await jsonBody(response), equals([_restaurant.toJson()]));
    });

    test('filters by cuisine when one is given', () async {
      final repository = MockRestaurantRepository();
      when(() => repository.findByCuisine(any()))
          .thenAnswer((_) async => [_restaurant]);
      final context = TestContext(
        request: jsonRequest('GET', query: {'cuisine': '2'}),
      )..provide<RestaurantRepository>(repository);

      final response = await restaurants.onRequest(context.context);

      expect(response.statusCode, equals(200));
      verify(() => repository.findByCuisine(2)).called(1);
    });

    test('filters by category when one is given', () async {
      final repository = MockRestaurantRepository();
      when(() => repository.findByCategory(any()))
          .thenAnswer((_) async => [_restaurant]);
      final context = TestContext(
        request: jsonRequest('GET', query: {'category': '3'}),
      )..provide<RestaurantRepository>(repository);

      final response = await restaurants.onRequest(context.context);

      expect(response.statusCode, equals(200));
      verify(() => repository.findByCategory(3)).called(1);
    });

    test('filters by both cuisine and category when both are given', () async {
      final repository = MockRestaurantRepository();
      when(() => repository.findByCuisine(any()))
          .thenAnswer((_) async => [_restaurant]);
      final context = TestContext(
        request: jsonRequest('GET', query: {'cuisine': '1', 'category': '999'}),
      )..provide<RestaurantRepository>(repository);

      final response = await restaurants.onRequest(context.context);

      expect(response.statusCode, equals(200));
      verify(() => repository.findByCuisine(1)).called(1);
      // _restaurant.category is 1, not 999, so the in-memory category filter
      // on top of findByCuisine's results excludes it.
      expect(await jsonBody(response), isEmpty);
    });

    // `?cuisine=abc` used to become a NULL parameter, quietly matching
    // nothing and returning an empty 200.
    test('responds 400 for a non-numeric cuisine', () async {
      final response = await invoke(
        jsonRequest('GET', query: {'cuisine': 'abc'}),
      );

      expect(response.statusCode, equals(400));
      expect(
        await jsonBody(response),
        equals({'error': 'cuisine must be an integer'}),
      );
    });

    test('responds 400 for a non-numeric category', () async {
      final response = await invoke(
        jsonRequest('GET', query: {'category': 'abc'}),
      );

      expect(response.statusCode, equals(400));
      expect(
        await jsonBody(response),
        equals({'error': 'category must be an integer'}),
      );
    });
  });

  group('GET /api/v1/restaurants/[id]', () {
    Future<Response> invoke(Request request, String id, {Restaurant? found}) {
      final repository = MockRestaurantRepository();
      when(() => repository.findById(any())).thenAnswer((_) async => found);
      final context = TestContext(request: request)
        ..provide<RestaurantRepository>(repository);
      return Future.value(context.context)
          .then((c) => restaurant_by_id.onRequest(c, id));
    }

    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(
        (request) => invoke(request, '1', found: _restaurant),
        allowed: {'GET'},
      );
    });

    test('responds 400 for a non-numeric id', () async {
      expect((await invoke(jsonRequest('GET'), 'abc')).statusCode, equals(400));
    });

    test('responds 404 for an unknown id', () async {
      expect((await invoke(jsonRequest('GET'), '999')).statusCode, equals(404));
    });

    test('responds 200 with the restaurant', () async {
      final response =
          await invoke(jsonRequest('GET'), '1', found: _restaurant);
      expect(await jsonBody(response), equals(_restaurant.toJson()));
    });
  });

  group('GET /api/v1/restaurants/[id]/products', () {
    Future<Response> invoke(
      Request request,
      String id, {
      Restaurant? restaurant = _restaurant,
      List<Product> found = const [],
    }) {
      final restaurantRepository = MockRestaurantRepository();
      when(() => restaurantRepository.findById(any()))
          .thenAnswer((_) async => restaurant);
      final productRepository = MockProductRepository();
      when(() => productRepository.findByRestaurant(any()))
          .thenAnswer((_) async => found);

      final context = TestContext(request: request)
        ..provide<RestaurantRepository>(restaurantRepository)
        ..provide<ProductRepository>(productRepository);
      return Future.value(context.context)
          .then((c) => restaurant_products.onRequest(c, id));
    }

    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(
        (request) => invoke(request, '1'),
        allowed: {'GET'},
      );
    });

    test('responds 400 for a non-numeric id', () async {
      expect((await invoke(jsonRequest('GET'), 'abc')).statusCode, equals(400));
    });

    // An unknown restaurant used to return an empty 200, indistinguishable
    // from a real restaurant with no products.
    test('responds 404 for an unknown restaurant', () async {
      final response = await invoke(
        jsonRequest('GET'),
        '999',
        restaurant: null,
      );
      expect(response.statusCode, equals(404));
    });

    test('responds 200 with an empty array for a restaurant with no products',
        () async {
      final response = await invoke(jsonRequest('GET'), '1');
      expect(response.statusCode, equals(200));
      expect(await jsonBody(response), isEmpty);
    });

    test('serialises products with restaurant_id', () async {
      final response = await invoke(jsonRequest('GET'), '1', found: [_product]);
      final json = await jsonBody(response) as List<dynamic>;
      expect((json.single as Map)['restaurant_id'], equals(1));
    });
  });
}
