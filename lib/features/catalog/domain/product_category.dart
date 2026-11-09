/// A model class representing a product category.
class ProductCategory {
  /// Constructs a [ProductCategory] with the given properties.
  const ProductCategory({
    required this.id,
    required this.titleEn,
    required this.titleRu,
    required this.titleUz,
    required this.icon,
  });

  /// Builds a [ProductCategory] from a database column map.
  factory ProductCategory.fromRow(Map<String, dynamic> row) {
    return ProductCategory(
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
