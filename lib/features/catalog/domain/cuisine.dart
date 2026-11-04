/// A model class representing a restaurant cuisine.
class Cuisine {
  /// Constructs a [Cuisine] with the given properties.
  const Cuisine({
    required this.id,
    required this.titleEn,
    required this.titleRu,
    required this.titleUz,
    required this.icon,
  });

  /// Builds a [Cuisine] from a database column map.
  factory Cuisine.fromRow(Map<String, dynamic> row) {
    return Cuisine(
      id: row['id'] as int,
      titleEn: row['title_en'] as String,
      titleRu: row['title_ru'] as String,
      titleUz: row['title_uz'] as String,
      icon: row['icon'] as String?,
    );
  }

  /// Cuisine identifier.
  final int id;

  /// English title.
  final String titleEn;

  /// Russian title.
  final String titleRu;

  /// Uzbek title.
  final String titleUz;

  /// URL of the cuisine icon, if any.
  final String? icon;

  /// The JSON representation of this cuisine.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title_en': titleEn,
        'title_ru': titleRu,
        'title_uz': titleUz,
        'icon': icon,
      };
}
