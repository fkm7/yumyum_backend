import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:yumyum_backend/features/favorites/application/favorites_service.dart';
import 'package:yumyum_backend/features/favorites/domain/favorite_repository.dart';

import '../../../helpers/entities.dart';
import '../../../helpers/test_context.dart';

void main() {
  late MockFavoriteRepository favorites;
  late MockProductRepository products;
  late MockRestaurantRepository restaurants;
  late FavoritesService service;

  setUpAll(() => registerFallbackValue(FavoriteType.product));

  setUp(() {
    favorites = MockFavoriteRepository();
    products = MockProductRepository();
    restaurants = MockRestaurantRepository();
    when(() => favorites.add(any(), any(), any())).thenAnswer((_) async {});
    when(() => products.findById(1)).thenAnswer((_) async => testProduct());
    when(() => products.findById(999)).thenAnswer((_) async => null);
    when(() => restaurants.findById(999)).thenAnswer((_) async => null);
    service = FavoritesService(
      favorites: favorites,
      products: products,
      restaurants: restaurants,
    );
  });

  test('favorites an existing product', () async {
    expect(await service.addProduct('user-1', 1), isNotNull);
    verify(() => favorites.add('user-1', FavoriteType.product, 1)).called(1);
  });

  // item_id is not a foreign key, so this check is the only thing stopping
  // favorites from pointing at nothing.
  test('writes nothing for an unknown product or restaurant', () async {
    expect(await service.addProduct('user-1', 999), isNull);
    expect(await service.addRestaurant('user-1', 999), isNull);
    verifyNever(() => favorites.add(any(), any(), any()));
  });
}
