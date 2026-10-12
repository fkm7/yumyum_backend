import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/auth/authenticated_user.dart';
import 'package:yumyum_backend/repositories/favorite_repository.dart';
import 'package:yumyum_backend/repositories/restaurant_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  return switch (context.request.method) {
    HttpMethod.get => await _list(context),
    HttpMethod.post => await _add(context),
    _ => Response(statusCode: 405),
  };
}

Future<Response> _list(RequestContext context) async {
  final user = context.read<AuthenticatedUser>();
  final ids = await context
      .read<FavoriteRepository>()
      .findIds(user.uid, FavoriteType.restaurant);
  final restaurants = await context.read<RestaurantRepository>().findByIds(ids);
  return Response.json(body: restaurants.map((r) => r.toJson()).toList());
}

Future<Response> _add(RequestContext context) async {
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

  final restaurant =
      await context.read<RestaurantRepository>().findById(restaurantId);
  if (restaurant == null) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Restaurant not found'},
    );
  }

  final user = context.read<AuthenticatedUser>();
  await context
      .read<FavoriteRepository>()
      .add(user.uid, FavoriteType.restaurant, restaurantId);

  return Response.json(statusCode: 201, body: restaurant.toJson());
}
