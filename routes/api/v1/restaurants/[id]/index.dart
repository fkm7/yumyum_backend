import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/repositories/restaurant_repository.dart';

FutureOr<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final restaurantId = int.tryParse(id);
  if (restaurantId == null) {
    return Response.json(statusCode: 400, body: {'error': 'Invalid id'});
  }

  final restaurant =
      await context.read<RestaurantRepository>().findById(restaurantId);
  if (restaurant == null) {
    return Response.json(statusCode: 404, body: {'error': 'Not found'});
  }

  return Response.json(body: restaurant.toJson());
}
