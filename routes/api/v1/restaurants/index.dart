import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/models/restaurant.dart';
import 'package:yumyum_backend/repositories/restaurant_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final repository = context.read<RestaurantRepository>();
  final query = context.request.uri.queryParameters;
  final rawCuisine = query['cuisine'];
  final rawCategory = query['category'];

  if (rawCuisine == null && rawCategory == null) {
    final all = await repository.findAll();
    return Response.json(body: all.map((r) => r.toJson()).toList());
  }

  // `?cuisine=abc`/`?category=abc` used to parse to null and be passed to the
  // query as NULL, which matched nothing and returned an empty 200 rather
  // than reporting the bad input.
  int? cuisineId;
  if (rawCuisine != null) {
    cuisineId = int.tryParse(rawCuisine);
    if (cuisineId == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'cuisine must be an integer'},
      );
    }
  }

  int? categoryId;
  if (rawCategory != null) {
    categoryId = int.tryParse(rawCategory);
    if (categoryId == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'category must be an integer'},
      );
    }
  }

  List<Restaurant> filtered;
  if (cuisineId != null && categoryId != null) {
    filtered = (await repository.findByCuisine(cuisineId))
        .where((r) => r.category.id == categoryId)
        .toList();
  } else if (cuisineId != null) {
    filtered = await repository.findByCuisine(cuisineId);
  } else {
    filtered = await repository.findByCategory(categoryId!);
  }

  return Response.json(body: filtered.map((r) => r.toJson()).toList());
}
