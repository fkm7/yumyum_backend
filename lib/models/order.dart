import 'package:delmer_backend/models/product.dart';

/// A line item captured on an order.
///
/// This is persisted as JSONB, so the key names below are a storage format as
/// well as a wire format: changing one changes how existing rows read back.
class OrderProduct {
  /// Constructs an [OrderProduct].
  const OrderProduct({
    required this.id,
    required this.price,
    required this.count,
    required this.subTotal,
    required this.status,
    required this.image,
    required this.titleEn,
    required this.titleRu,
    required this.titleUz,
    required this.category,
    required this.description,
    required this.institution,
  });

  /// Captures a [Product] at the requested [count], pricing the line.
  factory OrderProduct.from(Product product, int count) {
    return OrderProduct(
      id: product.id,
      price: product.price,
      count: count,
      subTotal: product.price * count,
      status: product.status,
      image: product.image,
      titleEn: product.titleEn,
      titleRu: product.titleRu,
      titleUz: product.titleUz,
      // Only the id is captured, matching the persisted JSONB shape; see the
      // class doc.
      category: product.category.id,
      description: product.description,
      institution: product.restaurantId,
    );
  }

  /// Rebuilds an [OrderProduct] from persisted JSONB.
  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    return OrderProduct(
      id: json['id'] as int,
      price: (json['price'] as num).toDouble(),
      count: json['count'] as int,
      subTotal: (json['sub_total'] as num).toDouble(),
      status: json['status'] as String?,
      image: json['image'] as String?,
      titleEn: json['title_en'] as String?,
      titleRu: json['title_ru'] as String?,
      titleUz: json['title_uz'] as String?,
      category: json['category'] as int?,
      description: json['description'] as String?,
      institution: json['institution'] as int?,
    );
  }

  /// Identifier of the ordered product.
  final int id;

  /// Unit price at the time the order was placed.
  final double price;

  /// How many units were ordered.
  final int count;

  /// Line total: [price] multiplied by [count].
  final double subTotal;

  /// Availability status at the time the order was placed.
  final String? status;

  /// URL of the product image.
  final String? image;

  /// English title.
  final String? titleEn;

  /// Russian title.
  final String? titleRu;

  /// Uzbek title.
  final String? titleUz;

  /// Identifier of the product's category.
  final int? category;

  /// Free-text description.
  final String? description;

  /// Identifier of the restaurant the product belongs to.
  final int? institution;

  /// The JSON representation of this line item.
  ///
  /// `total` duplicates [subTotal]. It previously carried the running cart
  /// total accumulated so far, which made it meaningless per line; it is kept
  /// only so existing clients keep parsing, and new clients should read
  /// `sub_total`.
  Map<String, dynamic> toJson() => {
        'id': id,
        'price': price,
        'total': subTotal,
        'count': count,
        'status': status,
        'image': image,
        'title_en': titleEn,
        'title_ru': titleRu,
        'title_uz': titleUz,
        'category': category,
        'sub_total': subTotal,
        'description': description,
        'institution': institution,
      };
}

/// A model class representing a placed order.
class Order {
  /// Constructs an [Order].
  const Order({
    required this.id,
    required this.userId,
    required this.cost,
    required this.status,
    required this.orderTime,
    required this.restaurantInfo,
    required this.products,
    required this.deliveryAddress,
    required this.courier,
    required this.paymentDetail,
  });

  /// Builds an [Order] from a database column map.
  factory Order.fromRow(Map<String, dynamic> row) {
    return Order(
      id: row['id'] as String,
      userId: row['user_id'] as String?,
      cost: (row['cost'] as num).toDouble(),
      status: row['status'] as String,
      orderTime: row['order_time'] as DateTime,
      restaurantInfo: row['restaurant_info'] as Map<String, dynamic>,
      products: (row['products'] as List<dynamic>)
          .map((e) => OrderProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      deliveryAddress: row['delivery_address'] as Map<String, dynamic>?,
      courier: row['courier'] as Map<String, dynamic>?,
      paymentDetail: row['payment_detail'] as Map<String, dynamic>?,
    );
  }

  /// Order identifier.
  final String id;

  /// Identifier of the user who placed the order.
  final String? userId;

  /// Total cost of the order.
  final double cost;

  /// Fulfilment status.
  final String status;

  /// When the order was placed.
  final DateTime orderTime;

  /// Snapshot of the restaurant at the time of ordering.
  final Map<String, dynamic> restaurantInfo;

  /// The ordered line items.
  final List<OrderProduct> products;

  /// Structured delivery address, if supplied.
  final Map<String, dynamic>? deliveryAddress;

  /// Assigned courier, if any.
  final Map<String, dynamic>? courier;

  /// Payment details, if any.
  final Map<String, dynamic>? paymentDetail;

  /// The JSON representation of this order.
  ///
  /// [orderTime] is serialised to ISO-8601 here rather than at each call site.
  Map<String, dynamic> toJson() => {
        'id': id,
        'cost': cost,
        'status': status,
        'order_time': orderTime.toIso8601String(),
        'restaurant_info': restaurantInfo,
        'products': products.map((p) => p.toJson()).toList(),
        'delivery_address': deliveryAddress,
        'courier': courier,
        'payment_detail': paymentDetail,
      };
}
