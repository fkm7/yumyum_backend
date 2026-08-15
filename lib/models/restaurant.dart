/// A model class representing a restaurant.
class Restaurant {
  /// Constructs a [Restaurant] with the given properties.
  const Restaurant({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.rating,
    required this.logo,
    required this.address,
    required this.image,
    required this.category,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.phoneNumber,
    required this.deliveryCost,
    required this.minDeliveryTime,
    required this.maxDeliveryTime,
    required this.freeDeliveryFrom,
    required this.productCategories,
  });

  /// Builds a [Restaurant] from a database column map.
  ///
  /// `address` and `product_categories` are `JSONB` columns, which the postgres
  /// driver returns already decoded — a [Map] and a [List] respectively, not
  /// JSON strings.
  factory Restaurant.fromRow(Map<String, dynamic> row) {
    return Restaurant(
      id: row['id'] as int,
      name: row['name'] as String,
      isOpen: row['is_open'] as bool,
      rating: (row['rating'] as num?)?.toDouble(),
      logo: row['logo'] as String?,
      address: row['address'] as Map<String, dynamic>,
      image: row['image'] as String?,
      category: row['category'] as int,
      startTime: row['start_time'] as String?,
      endTime: row['end_time'] as String?,
      description: row['description'] as String?,
      phoneNumber: row['phone_number'] as String?,
      deliveryCost: (row['delivery_cost'] as num?)?.toDouble(),
      minDeliveryTime: row['min_delivery_time'] as int?,
      maxDeliveryTime: row['max_delivery_time'] as int?,
      freeDeliveryFrom: (row['free_delivery_from'] as num?)?.toDouble(),
      productCategories: row['product_categories'] as List<dynamic>?,
    );
  }

  /// Restaurant identifier.
  final int id;

  /// Display name.
  final String name;

  /// Whether the restaurant is currently accepting orders.
  final bool isOpen;

  /// Average rating, if any.
  final double? rating;

  /// URL of the restaurant logo.
  final String? logo;

  /// Structured street address.
  final Map<String, dynamic> address;

  /// URL of the restaurant cover image.
  final String? image;

  /// Identifier of the category this restaurant belongs to.
  final int category;

  /// Opening time, as `HH:mm`.
  final String? startTime;

  /// Closing time, as `HH:mm`.
  final String? endTime;

  /// Free-text description.
  final String? description;

  /// Contact phone number.
  final String? phoneNumber;

  /// Flat delivery fee.
  final double? deliveryCost;

  /// Lower bound of the delivery estimate, in minutes.
  final int? minDeliveryTime;

  /// Upper bound of the delivery estimate, in minutes.
  final int? maxDeliveryTime;

  /// Order total above which delivery is free.
  final double? freeDeliveryFrom;

  /// Identifiers of the menu categories this restaurant offers.
  final List<dynamic>? productCategories;

  /// The JSON representation of this restaurant.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'is_open': isOpen,
        'rating': rating,
        'logo': logo,
        'address': address,
        'image': image,
        'category': category,
        'start_time': startTime,
        'end_time': endTime,
        'description': description,
        'phone_number': phoneNumber,
        'delivery_cost': deliveryCost,
        'min_delivery_time': minDeliveryTime,
        'max_delivery_time': maxDeliveryTime,
        'free_delivery_from': freeDeliveryFrom,
        'product_categories': productCategories,
      };
}
