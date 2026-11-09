/// One section of a restaurant's menu: a [id]-identified category that
/// restaurant [restaurantId] has at least one product in.
///
/// Unlike `Category`, it carries no icon (menu sections are rendered as
/// plain tabs/headers) but does carry its restaurant, so a client holding
/// only the section can fetch the products under it.
class MenuCategory {
  /// Constructs a [MenuCategory] with the given properties.
  const MenuCategory({
    required this.id,
    required this.restaurantId,
    required this.titleEn,
    required this.titleRu,
    required this.titleUz,
  });

  /// Builds a [MenuCategory] from a decoded JSONB object or column map.
  factory MenuCategory.fromRow(Map<String, dynamic> row) {
    return MenuCategory(
      id: row['id'] as int,
      restaurantId: row['restaurant_id'] as int,
      titleEn: row['title_en'] as String,
      titleRu: row['title_ru'] as String,
      titleUz: row['title_uz'] as String,
    );
  }

  /// The category's id: the same id `GET /api/v1/categories` returns and
  /// `?category=<id>` filters on.
  final int id;

  /// Identifier of the restaurant this section belongs to.
  final int restaurantId;

  /// English title.
  final String titleEn;

  /// Russian title.
  final String titleRu;

  /// Uzbek title.
  final String titleUz;

  /// The JSON representation of this menu section.
  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurant_id': restaurantId,
        'title_en': titleEn,
        'title_ru': titleRu,
        'title_uz': titleUz,
      };
}
