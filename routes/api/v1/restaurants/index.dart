import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:delmer_backend/repositories/restaurant_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final repository = context.read<RestaurantRepository>();
  final rawCategory = context.request.uri.queryParameters['category'];

  if (rawCategory == null) {
    final all = await repository.findAll();
    return Response.json(body: all.map((r) => r.toJson()).toList());
  }

  // `?category=abc` used to parse to null and be passed to the query as NULL,
  // which matched nothing and returned an empty 200 rather than reporting the
  // bad input.
  final categoryId = int.tryParse(rawCategory);
  if (categoryId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'category must be an integer'},
    );
  }

  final filtered = await repository.findByCategory(categoryId);
  return Response.json(body: filtered.map((r) => r.toJson()).toList());
}
