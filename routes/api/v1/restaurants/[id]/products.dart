import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/repositories/product_repository.dart';
import 'package:delmer_backend/repositories/restaurant_repository.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final restaurantId = int.tryParse(id);
  if (restaurantId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid id'});
  }

  // An unknown restaurant used to return an empty list with a 200, which is
  // indistinguishable from a real restaurant that has no products yet.
  final restaurant =
      await context.read<RestaurantRepository>().findById(restaurantId);
  if (restaurant == null) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Restaurant not found'},
    );
  }

  final products =
      await context.read<ProductRepository>().findByRestaurant(restaurantId);
  return Response.json(body: products.map((p) => p.toJson()).toList());
}
