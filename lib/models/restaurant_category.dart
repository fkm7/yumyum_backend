/// A model class representing the kind of food a restaurant is known for
/// (Burgers, Pizza, Sushi, ...), as distinct from its cuisine.
class RestaurantCategory {
  /// Constructs a [RestaurantCategory] with the given properties.
  const RestaurantCategory({
    required this.id,
    required this.titleEn,
    required this.titleRu,
    required this.titleUz,
    required this.icon,
  });

  /// Builds a [RestaurantCategory] from a database column map.
  factory RestaurantCategory.fromRow(Map<String, dynamic> row) {
    return RestaurantCategory(
      id: row['id'] as int,
      titleEn: row['title_en'] as String,
      titleRu: row['title_ru'] as String,
      titleUz: row['title_uz'] as String,
      icon: row['icon'] as String?,
    );
  }

  /// Restaurant category identifier.
  final int id;

  /// English title.
  final String titleEn;

  /// Russian title.
  final String titleRu;

  /// Uzbek title.
  final String titleUz;

  /// URL of the restaurant category icon, if any.
  final String? icon;

  /// The JSON representation of this restaurant category.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title_en': titleEn,
        'title_ru': titleRu,
        'title_uz': titleUz,
        'icon': icon,
      };
}
