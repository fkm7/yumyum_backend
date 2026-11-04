import 'package:yumyum_backend/features/catalog/domain/product.dart';
import 'package:yumyum_backend/features/catalog/domain/product_repository.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant_repository.dart';
import 'package:yumyum_backend/features/favorites/domain/favorite_repository.dart';

/// A user's favorite products and restaurants.
///
/// A favorite's item id is not a foreign key — it points at products or
/// restaurants depending on its type — so existence is checked here, before
/// anything is written.
class FavoritesService {
  /// Constructs a [FavoritesService].
  const FavoritesService({
    required FavoriteRepository favorites,
    required ProductRepository products,
    required RestaurantRepository restaurants,
  })  : _favorites = favorites,
        _products = products,
        _restaurants = restaurants;

  final FavoriteRepository _favorites;
  final ProductRepository _products;
  final RestaurantRepository _restaurants;

  /// The products [userId] has favorited.
  Future<List<Product>> products(String userId) async => _products
      .findByIds(await _favorites.findIds(userId, FavoriteType.product));

  /// The restaurants [userId] has favorited.
  Future<List<Restaurant>> restaurants(String userId) async =>
      _restaurants.findByIds(
        await _favorites.findIds(userId, FavoriteType.restaurant),
      );

  /// Favorites product [productId] and returns it, or returns null when no
  /// such product exists.
  Future<Product?> addProduct(String userId, int productId) async {
    final product = await _products.findById(productId);
    if (product == null) return null;
    await _favorites.add(userId, FavoriteType.product, productId);
    return product;
  }

  /// Favorites restaurant [restaurantId] and returns it, or returns null when
  /// no such restaurant exists.
  Future<Restaurant?> addRestaurant(String userId, int restaurantId) async {
    final restaurant = await _restaurants.findById(restaurantId);
    if (restaurant == null) return null;
    await _favorites.add(userId, FavoriteType.restaurant, restaurantId);
    return restaurant;
  }

  /// Removes product [productId] from [userId]'s favorites.
  Future<void> removeProduct(String userId, int productId) =>
      _favorites.remove(userId, FavoriteType.product, productId);

  /// Removes restaurant [restaurantId] from [userId]'s favorites.
  Future<void> removeRestaurant(String userId, int restaurantId) =>
      _favorites.remove(userId, FavoriteType.restaurant, restaurantId);
}
