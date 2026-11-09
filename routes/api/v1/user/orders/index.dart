import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/features/auth/presentation/authenticated_user.dart';
import 'package:yumyum_backend/features/orders/application/order_service.dart';
import 'package:yumyum_backend/features/orders/domain/build_order.dart';
import 'package:yumyum_backend/features/orders/domain/cart_item.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _getOrders(context),
    HttpMethod.post => await _createOrder(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _getOrders(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final orders = await context.read<OrderService>().list(user.uid);
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

  final addressId = body['addressId'];
  if (addressId is! String || addressId.isEmpty) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'addressId is required'},
    );
  }

  final paymentMethodId = body['paymentMethodId'];
  if (paymentMethodId != null &&
      (paymentMethodId is! String || paymentMethodId.isEmpty)) {
    return Response.json(
      statusCode: 422,
      body: {'error': 'paymentMethodId must be a string'},
    );
  }

  final result = await context.read<OrderService>().place(
        userId: context.read<AuthenticatedUser>().uid,
        restaurantId: restaurantId,
        items: requested,
        addressId: addressId,
        paymentMethodId: paymentMethodId as String?,
      );

  // Exhaustive over the sealed results: a new failure mode added to the
  // service or to buildOrder will not compile until it is handled here.
  // A foreign address or payment method is answered exactly like a missing
  // one, so a caller cannot probe other users' ids.
  return switch (result) {
    OrderPlaced(:final order) =>
      Response.json(statusCode: 201, body: order.toJson()),
    OrderAddressNotFound() => Response.json(
        statusCode: 404,
        body: {'error': 'Address not found'},
      ),
    OrderPaymentMethodNotFound() => Response.json(
        statusCode: 404,
        body: {'error': 'Payment method not found'},
      ),
    OrderRestaurantNotFound() => Response.json(
        statusCode: 404,
        body: {'error': 'Restaurant not found'},
      ),
    OrderRejected(:final reason) => _rejected(reason),
  };
}

Response _rejected(OrderBuildFailure reason) => switch (reason) {
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
          body: {
            'error': 'Products are unavailable',
            'product_ids': productIds,
          },
        ),
    };
