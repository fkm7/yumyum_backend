import 'package:dart_frog/dart_frog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:yumyum_backend/features/catalog/domain/category.dart';
import 'package:yumyum_backend/features/catalog/domain/category_repository.dart';
import 'package:yumyum_backend/features/catalog/domain/cuisine.dart';
import 'package:yumyum_backend/features/catalog/domain/cuisine_repository.dart';
import 'package:yumyum_backend/features/catalog/domain/menu_category.dart';
import 'package:yumyum_backend/features/catalog/domain/product.dart';
import 'package:yumyum_backend/features/catalog/domain/product_category.dart';
import 'package:yumyum_backend/features/catalog/domain/product_category_repository.dart';
import 'package:yumyum_backend/features/catalog/domain/product_repository.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant_repository.dart';

import '../../../../routes/api/v1/categories/index.dart' as categories;
import '../../../../routes/api/v1/cuisines/index.dart' as cuisines;
import '../../../../routes/api/v1/product-categories/index.dart' as categories;
import '../../../../routes/api/v1/products/[id].dart' as product_by_id;
import '../../../../routes/api/v1/products/index.dart' as products;
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

const _menuCategory = MenuCategory(
  id: 1,
  restaurantId: 1,
  titleEn: 'Burgers',
  titleRu: 'Бургеры',
  titleUz: 'Burgerlar',
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
  startTime: '09:00',
  endTime: '23:00',
  description: null,
  phoneNumber: null,
  deliveryCost: 5000,
  minDeliveryTime: 20,
  maxDeliveryTime: 40,
  freeDeliveryFrom: 50000,
  menuCategories: [_menuCategory],
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

  group('GET /api/v1/products', () {
    Future<Response> invoke(Request request, {List<Product> found = const []}) {
      final repository = MockProductRepository();
      when(() => repository.findAll(categoryId: any(named: 'categoryId')))
          .thenAnswer((_) async => found);
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

    test('returns every product when no category is given', () async {
      final repository = MockProductRepository();
      when(() => repository.findAll(categoryId: any(named: 'categoryId')))
          .thenAnswer((_) async => [_product]);
      final context = TestContext(request: jsonRequest('GET'))
        ..provide<ProductRepository>(repository);

      await products.onRequest(context.context);

      verify(repository.findAll).called(1);
    });

    test('filters by category when one is given', () async {
      final repository = MockProductRepository();
      when(() => repository.findAll(categoryId: any(named: 'categoryId')))
          .thenAnswer((_) async => [_product]);
      final context = TestContext(
        request: jsonRequest('GET', query: {'category': '1'}),
      )..provide<ProductRepository>(repository);

      final response = await products.onRequest(context.context);

      expect(response.statusCode, equals(200));
      verify(() => repository.findAll(categoryId: 1)).called(1);
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
    MockRestaurantRepository repositoryReturning(List<Restaurant> found) {
      final repository = MockRestaurantRepository();
      when(
        () => repository.findAll(
          cuisineId: any(named: 'cuisineId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => found);
      return repository;
    }

    Future<Response> invoke(
      Request request, {
      List<Restaurant> found = const [],
    }) {
      final context = TestContext(request: request)
        ..provide<RestaurantRepository>(repositoryReturning(found));
      return Future.value(context.context).then(restaurants.onRequest);
    }

    Future<MockRestaurantRepository> invokeWithQuery(
      Map<String, String> query,
    ) async {
      final repository = repositoryReturning([_restaurant]);
      final context = TestContext(request: jsonRequest('GET', query: query))
        ..provide<RestaurantRepository>(repository);
      final response = await restaurants.onRequest(context.context);
      expect(response.statusCode, equals(200));
      return repository;
    }

    test('rejects every method except GET', () async {
      await expectMethodNotAllowed(invoke, allowed: {'GET'});
    });

    test('serialises restaurants with their menu categories', () async {
      final response = await invoke(jsonRequest('GET'), found: [_restaurant]);
      final body = await jsonBody(response) as List<dynamic>;

      expect(body, equals([_restaurant.toJson()]));
      expect(
        (body.single as Map<String, dynamic>)['menu_categories'],
        equals([
          {
            'id': 1,
            'restaurant_id': 1,
            'title_en': 'Burgers',
            'title_ru': 'Бургеры',
            'title_uz': 'Burgerlar',
          },
        ]),
      );
    });

    test('returns every restaurant when no filter is given', () async {
      final repository = await invokeWithQuery({});
      verify(repository.findAll).called(1);
    });

    test('filters by cuisine when one is given', () async {
      final repository = await invokeWithQuery({'cuisine': '2'});
      verify(() => repository.findAll(cuisineId: 2)).called(1);
    });

    // The search screen's category tap: restaurants serving that food.
    test('filters by category when one is given', () async {
      final repository = await invokeWithQuery({'category': '3'});
      verify(() => repository.findAll(categoryId: 3)).called(1);
    });

    test('filters by both cuisine and category when both are given', () async {
      final repository =
          await invokeWithQuery({'cuisine': '1', 'category': '3'});
      verify(() => repository.findAll(cuisineId: 1, categoryId: 3)).called(1);
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
