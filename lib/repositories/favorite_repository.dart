/// The kind of item a favorite points at.
enum FavoriteType {
  /// A favorited restaurant.
  restaurant('restaurant'),

  /// A favorited product.
  product('product');

  const FavoriteType(this.value);

  /// The value stored in the `item_type` column.
  final String value;
}

/// Read and write access to the `favorites` table.
abstract class FavoriteRepository {
  /// Marks [itemId] as a [type] favorite of [userId].
  ///
  /// Idempotent: favoriting an already-favorited item is a no-op.
  Future<void> add(String userId, FavoriteType type, int itemId);

  /// Unmarks [itemId] as a [type] favorite of [userId].
  ///
  /// A no-op when the item was not favorited.
  Future<void> remove(String userId, FavoriteType type, int itemId);

  /// Returns the ids of [userId]'s [type] favorites, most recently
  /// favorited first.
  Future<List<int>> findIds(String userId, FavoriteType type);
}
