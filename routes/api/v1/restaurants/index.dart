import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/core/http/query_params.dart';
import 'package:yumyum_backend/features/catalog/domain/restaurant_repository.dart';

/// `GET /api/v1/restaurants[?cuisine=<id>][&category=<id>]`
///
/// `category` returns every restaurant with at least one product in that
/// category, which is what the search screen lists when a category is
/// tapped. Given together, both filters must match.
FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final (cuisineId, badCuisine) = intQueryParam(context, 'cuisine');
  if (badCuisine != null) return badCuisine;
  final (categoryId, badCategory) = intQueryParam(context, 'category');
  if (badCategory != null) return badCategory;

  final restaurants = await context
      .read<RestaurantRepository>()
      .findAll(cuisineId: cuisineId, categoryId: categoryId);
  return Response.json(body: restaurants.map((r) => r.toJson()).toList());
}
