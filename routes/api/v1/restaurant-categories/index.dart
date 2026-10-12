import 'dart:async';

import 'package:dart_frog/dart_frog.dart';
import 'package:yumyum_backend/repositories/restaurant_category_repository.dart';

FutureOr<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final categories =
      await context.read<RestaurantCategoryRepository>().findAll();
  return Response.json(body: categories.map((c) => c.toJson()).toList());
}
