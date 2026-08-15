/// A model class representing a product on a restaurant's menu.
class Product {
  /// Constructs a [Product] with the given properties.
  const Product({
    required this.id,
    required this.restaurantId,
    required this.category,
    required this.price,
    required this.status,
    required this.titleEn,
    required this.titleRu,
    required this.titleUz,
    required this.image,
    required this.description,
  });

  /// Builds a [Product] from a database column map.
  ///
  /// `price` is read as [num] before being widened: PostgreSQL
  /// `DOUBLE PRECISION` arrives as a [double], but an `INTEGER` or `NUMERIC`
  /// column in an older database would arrive as an [int].
  factory Product.fromRow(Map<String, dynamic> row) {
    return Product(
      id: row['id'] as int,
      restaurantId: row['restaurant_id'] as int,
      category: row['category'] as int,
      price: (row['price'] as num).toDouble(),
      status: row['status'] as String,
      titleEn: row['title_en'] as String,
      titleRu: row['title_ru'] as String?,
      titleUz: row['title_uz'] as String?,
      image: row['image'] as String?,
      description: row['description'] as String?,
    );
  }

  /// Product identifier.
  final int id;

  /// Identifier of the restaurant this product belongs to.
  final int restaurantId;

  /// Identifier of the category this product belongs to.
  final int category;

  /// Unit price.
  final double price;

  /// Availability status.
  final String status;

  /// English title.
  final String titleEn;

  /// Russian title.
  final String? titleRu;

  /// Uzbek title.
  final String? titleUz;

  /// URL of the product image.
  final String? image;

  /// Free-text description.
  final String? description;

  /// The JSON representation of this product.
  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurant_id': restaurantId,
        'category': category,
        'price': price,
        'status': status,
        'title_en': titleEn,
        'title_ru': titleRu,
        'title_uz': titleUz,
        'image': image,
        'description': description,
      };
}
