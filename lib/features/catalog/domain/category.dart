/// A model class representing a product category.
class Category {
  /// Constructs a [Category] with the given properties.
  const Category({
    required this.id,
    required this.titleEn,
    required this.titleRu,
    required this.titleUz,
    required this.icon,
  });

  /// Builds a [Category] from a database column map.
  factory Category.fromRow(Map<String, dynamic> row) {
    return Category(
      id: row['id'] as int,
      titleEn: row['title_en'] as String,
      titleRu: row['title_ru'] as String,
      titleUz: row['title_uz'] as String,
      icon: row['icon'] as String?,
    );
  }

  /// Category identifier.
  final int id;

  /// English title.
  final String titleEn;

  /// Russian title.
  final String titleRu;

  /// Uzbek title.
  final String titleUz;

  /// URL of the category icon, if any.
  final String? icon;

  /// The JSON representation of this category.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title_en': titleEn,
        'title_ru': titleRu,
        'title_uz': titleUz,
        'icon': icon,
      };
}
