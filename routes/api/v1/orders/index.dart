import 'dart:async';
import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/db/database_service.dart';
import 'package:postgres/postgres.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _getOrders(context),
    HttpMethod.post => await _createOrder(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _createOrder(RequestContext context) async {
  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final restaurantId = body['restaurantId'] as int?;
  final orderProducts = body['products'] as List<dynamic>?;

  if (restaurantId == null || orderProducts == null || orderProducts.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'restaurantId and products are required'},
    );
  }

  final conn = await context.read<DatabaseService>().connection;

  final restaurantResult = await conn.execute(
    Sql.named('''
      SELECT id, name, is_open, rating, logo, address, image, category,
             start_time, end_time, description, phone_number, delivery_cost,
             min_delivery_time, max_delivery_time, free_delivery_from,
             product_categories
      FROM restaurants WHERE id = @id
    '''),
    parameters: {'id': restaurantId},
  );
  if (restaurantResult.isEmpty) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Restaurant not found'},
    );
  }
  final restaurant = restaurantResult.first.toColumnMap();

  final orderedProducts = <Map<String, dynamic>>[];
  var cost = 0.0;

  for (final item in orderProducts) {
    final itemMap = item as Map<String, dynamic>;
    final productId = itemMap['id'] as int;
    final count = (itemMap['count'] as int?) ?? 1;

    final productResult = await conn.execute(
      Sql.named('''
        SELECT id, restaurant_id AS restaurant, category, price, status,
               title_en, title_ru, title_uz, image, description
        FROM products WHERE id = @id
      '''),
      parameters: {'id': productId},
    );
    if (productResult.isEmpty) continue;
    final product = productResult.first.toColumnMap();

    final price = (product['price'] as num).toDouble();
    final subTotal = price * count;
    cost += subTotal;

    orderedProducts.add({
      'id': product['id'],
      'price': price,
      'total': cost,
      'count': count,
      'status': product['status'],
      'image': product['image'],
      'title_en': product['title_en'],
      'title_ru': product['title_ru'],
      'title_uz': product['title_uz'],
      'category': product['category'],
      'sub_total': subTotal,
      'description': product['description'],
      'institution': product['restaurant'],
    });
  }

  final orderId = DateTime.now().millisecondsSinceEpoch.toString();
  final orderTime = DateTime.now();
  final deliveryAddress = body['deliveryAddress'] as Map<String, dynamic>?;

  await conn.execute(
    Sql.named('''
      INSERT INTO orders
        (id, cost, status, order_time, restaurant_info, products, delivery_address, courier, payment_detail)
      VALUES
        (@id, @cost, @status, @order_time, @restaurant_info::jsonb, @products::jsonb, @delivery_address::jsonb, NULL, NULL)
    '''),
    parameters: {
      'id': orderId,
      'cost': cost,
      'status': 'received',
      'order_time': orderTime,
      'restaurant_info': jsonEncode(restaurant),
      'products': jsonEncode(orderedProducts),
      'delivery_address':
          deliveryAddress == null ? null : jsonEncode(deliveryAddress),
    },
  );

  return Response.json(
    statusCode: 201,
    body: {
      'id': orderId,
      'cost': cost,
      'status': 'received',
      'order_time': orderTime.toIso8601String(),
      'restaurant_info': restaurant,
      'products': orderedProducts,
      'delivery_address': deliveryAddress,
      'courier': null,
      'payment_detail': null,
    },
  );
}

Future<Response> _getOrders(RequestContext context) async {
  final conn = await context.read<DatabaseService>().connection;
  final result = await conn.execute('''
    SELECT id, cost, status, order_time, restaurant_info, products,
           delivery_address, courier, payment_detail
    FROM orders ORDER BY order_time DESC
  ''');

  final orders = result.map((row) {
    final order = row.toColumnMap();
    order['order_time'] = (order['order_time'] as DateTime).toIso8601String();
    return order;
  }).toList();

  return Response.json(body: orders);
}
