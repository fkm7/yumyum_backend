import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/auth/authenticated_user.dart';
import 'package:delmer_backend/models/cart_item.dart';
import 'package:delmer_backend/models/order.dart';
import 'package:delmer_backend/repositories/order_repository.dart';
import 'package:delmer_backend/repositories/product_repository.dart';
import 'package:delmer_backend/repositories/restaurant_repository.dart';
import 'package:delmer_backend/services/order_service.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _getOrders(context),
    HttpMethod.post => await _createOrder(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _getOrders(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final orders = await context.read<OrderRepository>().findByUser(user.uid);
  return Response.json(body: orders.map((o) => o.toJson()).toList());
}

Future<Response> _createOrder(RequestContext context) async {
  final Map<String, dynamic> body;
  try {
    body = await context.request.json() as Map<String, dynamic>;
  } catch (_) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid JSON'});
  }

  final restaurantId = body['restaurantId'];
  if (restaurantId is! int) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'restaurantId is required and must be an integer'},
    );
  }

  final rawProducts = body['products'];
  if (rawProducts is! List || rawProducts.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'products is required and must be a non-empty array'},
    );
  }

  // Parsing is total: a malformed entry yields null and a 422, where the
  // previous `as int` casts threw and surfaced as a 500.
  final requested = <CartItem>[];
  for (final entry in rawProducts) {
    final item = CartItem.tryParse(entry);
    if (item == null) {
      return Response.json(
        statusCode: 422,
        body: {
          'error': 'each product needs an integer id and a positive count',
        },
      );
    }
    requested.add(item);
  }

  final restaurant =
      await context.read<RestaurantRepository>().findById(restaurantId);
  if (restaurant == null) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Restaurant not found'},
    );
  }

  final available = await context
      .read<ProductRepository>()
      .findByIds(requested.map((i) => i.productId).toList());

  final result = buildOrder(
    orderId: _uuid.v4(),
    userId: context.read<AuthenticatedUser>().uid,
    restaurant: restaurant,
    available: available,
    requested: requested,
    orderTime: DateTime.now().toUtc(),
    deliveryAddress: body['deliveryAddress'] as Map<String, dynamic>?,
  );

  // Exhaustive over the sealed OrderBuildResult: a new failure mode added to
  // the service will not compile until it is handled here.
  return switch (result) {
    OrderBuilt(:final order) => await _persist(context, order),
    EmptyCart() => Response.json(
        statusCode: 422,
        body: {'error': 'products is required and must be a non-empty array'},
      ),
    RestaurantClosed() => Response.json(
        statusCode: 409,
        body: {'error': 'Restaurant is currently closed'},
      ),
    ProductsNotFound(:final productIds) => Response.json(
        statusCode: 404,
        body: {'error': 'Products not found', 'product_ids': productIds},
      ),
    ProductsFromOtherRestaurant(:final productIds) => Response.json(
        statusCode: 422,
        body: {
          'error': 'Products do not belong to this restaurant',
          'product_ids': productIds,
        },
      ),
    ProductsUnavailable(:final productIds) => Response.json(
        statusCode: 409,
        body: {'error': 'Products are unavailable', 'product_ids': productIds},
      ),
  };
}

Future<Response> _persist(RequestContext context, Order order) async {
  final saved = await context.read<OrderRepository>().create(order);
  return Response.json(statusCode: 201, body: saved.toJson());
}
